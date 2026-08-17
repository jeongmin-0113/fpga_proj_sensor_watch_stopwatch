# Team Integration Contract

## Purpose

민성 담당인 SR04, Project Control Unit, Top을 팀원 담당 UART/FIFO 및 ASCII
codec과 결합하기 위한 경계 규격입니다. 이 브랜치는 팀원 RTL을 직접 수정하지
않으며, 해당 브랜치가 합류하면 이 문서의 신호만 맞춰 연결합니다.

## Ownership and change policy

| 영역 | 담당 | 이 브랜치 정책 |
|---|---|---|
| ASCII decoder / encoder | 정민 | 원본 유지, 공개 포트만 소비 |
| FIFO / UART RX·TX | 정민 | 원본 유지, Top glue에서 인스턴스 |
| DHT11 / Stopwatch 등 | 각 담당자 | 원본 유지 |
| HC-SR04 | 민성 | 구현·TB 담당 |
| Project Control Unit | 민성 | 구현·TB 담당 |
| Integrated Top / glue | 민성 | 인터페이스 연결·통합 TB 담당 |

## Decoder → Control Unit

현재 `main`의 `ascii_decoder` 공개 출력과 직접 연결합니다.

| 신호 | 폭 | 의미 |
|---|---:|---|
| `o_done` | 1 | decode 결과가 유효한 1-cycle event |
| `o_signals` | 10 | run, stop, clear, mode, save, load, up, down, left, right one-hot |
| `o_target` | 4 | stopwatch, watch, distance, temp/humidity query one-hot |
| `o_op` | 1 | `0`: one-byte `o_signals`, `1`: multi-byte `o_target`; Control은 선택된 벡터만 해석 |

목표 문자열 `/get_run`, `/get_stop`, `/get_dist`, `/get_temp_hum`의 파싱은
decoder 담당입니다. 문자열이 위 one-hot 출력으로 변환되면 Top과 Control Unit은
변경하지 않습니다. invalid-command 출력이 추가되면 Control의 `i_cmd_error`에
연결하며, 현재 공개 버전에서는 이 입력을 0으로 고정합니다.

## Control Unit → Encoder proposal

Encoder 합류 전에 정민님과 아래 의미를 합의합니다. 포트명은 변경 가능하지만
handshake 의미는 유지해야 합니다.

| 신호 | 방향 | 의미 |
|---|---|---|
| `response_valid` | Control → Encoder | 응답 요청 유효, ready까지 유지 |
| `response_kind[2:0]` | Control → Encoder | ACK, ERROR, SW, WATCH, DIST, DHT11 |
| `response_ready` | Encoder → Control | 새 응답 요청을 받을 수 있음 |
| 시간/거리/온습도 값 | Top → Encoder | kind에 맞는 payload snapshot |
| TX data/push/full | Encoder ↔ TX FIFO | full일 때 push 금지, 이후 이어서 전송 |

Encoder가 아직 `main`에 없으므로 현재 Top은 `tx=1'b1`로 유지합니다. 임시 encoder를
추가해 담당자 구현을 덮지 않습니다.

## Current upstream integration blockers

2026-08-16 기준 공개 `main`에서 확인한 사항입니다.

1. `fifo.v`에 선언되지 않은 `c_state`, `n_state`, `EMPTY` 참조 3개가 있습니다.
2. `clock.v`와 `stopwatch_datapath.v`가 모두 `time_counter`를 선언합니다.
3. `dht11_controller.v`가 저장소에 없는 `ila_0` IP를 인스턴스합니다.
4. `ascii_encoder.v`는 아직 공개 `main`에 없습니다.

원본 변경을 피하기 위해 build 단계가 `build/generated/`에만 다음을 수행합니다.

- FIFO의 미선언 FSM 잔재 제거와 helper 이름 namespace 처리
- Watch/Stopwatch helper module 이름 namespace 처리
- non-debug synthesis용 empty ILA integration stub 사용

`build/generated/`는 git에 포함하지 않으며 팀원 수정본이 합류하면 이 우회 처리를
하나씩 제거합니다.

## Merge checklist

- [ ] 정민님 decoder branch/ref 확인
- [ ] `/get_run`, `/get_stop`, `/get_dist`, `/get_temp_hum` one-hot mapping 합의
- [ ] encoder port와 backpressure handshake 합의
- [ ] 팀원 브랜치 merge 후 generated workaround 필요 여부 재검토
- [ ] Top UART TX end-to-end TB 추가
- [ ] Vivado 2020.2 전체 simulation/synthesis/implementation 재실행

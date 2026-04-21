<img width="1486" height="778" alt="결과" src="https://github.com/user-attachments/assets/20c8cd85-4b42-41c3-9fb7-37a39d70cf64" />

enc_a = 1 입력
    ↓ 매 클럭마다 shift
클럭1: phase_a_tmp = 0001
클럭2: phase_a_tmp = 0011
클럭3: phase_a_tmp = 0111
클럭4: phase_a_tmp = 1111 ← 4개 모두 1

phase_a_tmp = "1111" 확인
    ↓ 연속 3클럭 동안 유지 확인
클럭5: phase_a_filter = 01
클럭6: phase_a_filter = 02
클럭7: phase_a_filter = 03 ← filter_enc_config(3) 도달
    ↓
phase_a_exe = 1 확정

phase_a_exe_d1 = 0 (이전값)
phase_a_exe    = 1 (현재값)
    ↓ 조합논리 즉시
phase_a_r = not(0) and 1 = 1 ← 상승엣지 펄스 발생

phase_a_r = 1 감지
    ↓
count_enc_enable <= '1'  ← 이번 클럭에 설정
count_enc_dir    <= '0'  ← 정방향

count_enc_enable = 1 (이전 클럭에서 설정된 값)
    ↓
cnt_enc_local <= cnt_enc_local + 1

counter_data(1) <= cnt_enc_local
    ↓
watch_counter_data 변화

<img width="1486" height="778" alt="결과" src="https://github.com/user-attachments/assets/20c8cd85-4b42-41c3-9fb7-37a39d70cf64" />

## 📌 Encoder Phase A Processing Flow

### 1️⃣ Input & Shift

```text
enc_a = 1 입력

매 클럭마다 shift
클럭1: phase_a_tmp = 0001
클럭2: phase_a_tmp = 0011
클럭3: phase_a_tmp = 0111
클럭4: phase_a_tmp = 1111  ← 4개 모두 1 (안정 상태)
```

---

### 2️⃣ Filtering (Noise 제거)

```text
phase_a_tmp = "1111" 확인

연속 3클럭 동안 유지 확인
클럭5: phase_a_filter = 01
클럭6: phase_a_filter = 02
클럭7: phase_a_filter = 03  ← filter_enc_config(3) 도달

→ phase_a_exe = 1 확정
```

---

### 3️⃣ Rising Edge Detection

```text
phase_a_exe_d1 = 0 (이전값)
phase_a_exe    = 1 (현재값)

phase_a_r = not(phase_a_exe_d1) and phase_a_exe
          = 1  ← 상승 엣지 발생
```

---

### 4️⃣ Counter Trigger

```text
phase_a_r = 1 감지

count_enc_enable <= '1'
count_enc_dir    <= '0'  ← 정방향
```

---

### 5️⃣ Counter Update

```text
count_enc_enable = 1 (이전 클럭에서 설정된 값)

cnt_enc_local <= cnt_enc_local + 1
counter_data(1) <= cnt_enc_local

→ watch_counter_data 변화
```

---

### 🔥 Summary

```text
입력 → Shift → 안정화(1111) → 필터링(3클럭)
→ Rising Edge 검출 → Enable 발생 → 카운터 증가
```

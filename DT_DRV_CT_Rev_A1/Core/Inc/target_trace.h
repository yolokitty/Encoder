///* target_trace.h */
//#ifndef TARGET_TRACE_H
//#define TARGET_TRACE_H
//
//#include "main.h"
//
//typedef struct
//{
//    uint32_t magic;
//    uint32_t boot_count;
//    uint32_t reset_flags;
//
//    uint32_t seq;
//    uint32_t state;
//    uint32_t addr;
//    uint32_t data;
//    uint32_t tick;
//    uint32_t line;
//
//    uint32_t last_ok_state;
//    uint32_t last_ok_value;
//    uint32_t last_ok_tick;
//} target_trace_t;
//
//extern volatile target_trace_t g_trace_prev;
//extern volatile uint32_t g_trace_prev_valid;
//
//void TargetTrace_Init(void);
//void TargetTrace_Mark(uint32_t state, uint32_t addr, uint32_t data, uint32_t line);
//void TargetTrace_CommitOk(uint32_t state, uint32_t value);
//void TargetTrace_Heartbeat(uint32_t state);
//uint32_t TargetTrace_IwdgStart(void);
//void TargetTrace_IwdgKick(void);
//
//#define TRACE_MARK(st, addr, data) \
//    TargetTrace_Mark((st), (uint32_t)(addr), (uint32_t)(data), __LINE__)
//
//enum
//{
//    TRACE_MAGIC = 0x54524345u,
//
//    TRACE_ST_BOOT          = 0x0001,
//    TRACE_ST_MAIN_LOOP     = 0x0002,
//
//    TRACE_ST_ENC_LSB_BEGIN = 0x0201,
//    TRACE_ST_ENC_LSB_END   = 0x0202,
//    TRACE_ST_ENC_MSB_BEGIN = 0x0203,
//    TRACE_ST_ENC_MSB_END   = 0x0204,
//
//    TRACE_ST_IWDG_START_BEGIN   = 0x0301,
//    TRACE_ST_IWDG_WAIT_SR       = 0x0302,
//    TRACE_ST_IWDG_START_DONE    = 0x0303,
//    TRACE_ST_IWDG_START_TIMEOUT = 0x03EE,
//};
//
//#endif

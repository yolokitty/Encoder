///* target_trace.c */
//#include "target_trace.h"
//
//__attribute__((section(".noinit_d3"), used))
//static volatile target_trace_t g_trace_nv;
//
//volatile target_trace_t g_trace_prev;
//volatile uint32_t g_trace_prev_valid = 0;
//
//static void Trace_Clear(volatile target_trace_t *p)
//{
//    volatile uint32_t *w = (volatile uint32_t *)p;
//    uint32_t i;
//
//    for (i = 0; i < (sizeof(target_trace_t) / sizeof(uint32_t)); i++)
//    {
//        w[i] = 0u;
//    }
//}
//
//static void Trace_Copy(volatile target_trace_t *dst, volatile target_trace_t *src)
//{
//    volatile uint32_t *d = (volatile uint32_t *)dst;
//    volatile uint32_t *s = (volatile uint32_t *)src;
//    uint32_t i;
//
//    for (i = 0; i < (sizeof(target_trace_t) / sizeof(uint32_t)); i++)
//    {
//        d[i] = s[i];
//    }
//}
//
//void TargetTrace_Init(void)
//{
//    uint32_t reset_flags = RCC->RSR;
//
//    if (g_trace_nv.magic != TRACE_MAGIC)
//    {
//        Trace_Clear(&g_trace_nv);
//        g_trace_nv.magic = TRACE_MAGIC;
//        g_trace_prev_valid = 0u;
//    }
//    else
//    {
//        Trace_Copy(&g_trace_prev, &g_trace_nv);
//        g_trace_prev_valid = 1u;
//    }
//
//    __HAL_RCC_CLEAR_RESET_FLAGS();
//
//    g_trace_nv.boot_count += 1u;
//    g_trace_nv.reset_flags = reset_flags;
//    g_trace_nv.seq += 1u;
//    g_trace_nv.state = TRACE_ST_BOOT;
//    g_trace_nv.addr = 0u;
//    g_trace_nv.data = 0u;
//    g_trace_nv.tick = HAL_GetTick();
//    g_trace_nv.line = __LINE__;
//    g_trace_nv.last_ok_state = 0u;
//    g_trace_nv.last_ok_value = 0u;
//    g_trace_nv.last_ok_tick = 0u;
//    __DSB();
//}
//
//void TargetTrace_Mark(uint32_t state, uint32_t addr, uint32_t data, uint32_t line)
//{
//    g_trace_nv.seq += 1u;
//    g_trace_nv.state = state;
//    g_trace_nv.addr = addr;
//    g_trace_nv.data = data;
//    g_trace_nv.tick = HAL_GetTick();
//    g_trace_nv.line = line;
//    __DSB();
//}
//
//void TargetTrace_CommitOk(uint32_t state, uint32_t value)
//{
//    g_trace_nv.seq += 1u;
//    g_trace_nv.state = state;
//    g_trace_nv.data = value;
//    g_trace_nv.tick = HAL_GetTick();
//    g_trace_nv.last_ok_state = state;
//    g_trace_nv.last_ok_value = value;
//    g_trace_nv.last_ok_tick = g_trace_nv.tick;
//    __DSB();
//}
//
//void TargetTrace_Heartbeat(uint32_t state)
//{
//    g_trace_nv.seq += 1u;
//    g_trace_nv.state = state;
//    g_trace_nv.tick = HAL_GetTick();
//    __DSB();
//}
//
//uint32_t TargetTrace_IwdgStart(void)
//{
//    uint32_t start_tick;
//
//    TargetTrace_Mark(TRACE_ST_IWDG_START_BEGIN, 0u, IWDG1->SR, __LINE__);
//
//    IWDG1->KR = 0xCCCCu;
//    IWDG1->KR = 0x5555u;
//    IWDG1->PR = 6u;
//    IWDG1->RLR = 1250u;
//
//    start_tick = HAL_GetTick();
//    TargetTrace_Mark(TRACE_ST_IWDG_WAIT_SR, 0u, IWDG1->SR, __LINE__);
//
//    while (IWDG1->SR & (IWDG_SR_PVU | IWDG_SR_RVU))
//    {
//        if ((HAL_GetTick() - start_tick) > 500u)
//        {
//            TargetTrace_Mark(TRACE_ST_IWDG_START_TIMEOUT, 0u, IWDG1->SR, __LINE__);
//            return 0u;
//        }
//    }
//
//    IWDG1->KR = 0xAAAAu;
//    TargetTrace_Mark(TRACE_ST_IWDG_START_DONE, 0u, IWDG1->SR, __LINE__);
//    return 1u;
//}
//
//
//void TargetTrace_IwdgKick(void)
//{
//    IWDG1->KR = 0xAAAAu;
//}

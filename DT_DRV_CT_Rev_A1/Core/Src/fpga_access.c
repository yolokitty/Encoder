/*
 * fpga_access.c
 *
 *  Created on: Jun 7, 2024
 *      Author: Andy KUM
 */
#include "fpga_access.h"

void WriteRegData32(uint16_t usIndex, uint32_t ulData)
{
    volatile uint16_t usTemp;
    uint16_t usLsb = (uint16_t)(ulData & 0xFFFF);
    uint16_t usMsb = (uint16_t)((ulData >> 16) & 0xFFFF);

    *(volatile uint16_t*)ADDR_LSB_WR_PORT_DATA = usLsb;
    usTemp = *(volatile uint16_t*)ADDR_LSB_WR_PORT_DATA;
    if(usTemp != usLsb)
        usTemp = *(volatile uint16_t*)ADDR_LSB_WR_PORT_DATA;

    *(volatile uint16_t*)ADDR_MSB_WR_PORT_DATA = usMsb;
    usTemp = *(volatile uint16_t*)ADDR_MSB_WR_PORT_DATA;
    if(usTemp != usMsb)
        usTemp = *(volatile uint16_t*)ADDR_MSB_WR_PORT_DATA;

    *(volatile uint16_t*)ADDR_WR_CMD_PORT = (uint16_t)usIndex;
    usTemp = *(volatile uint16_t*)ADDR_WR_CMD_PORT;
    if(usTemp != (uint16_t)usIndex)
        usTemp = *(volatile uint16_t*)ADDR_WR_CMD_PORT;

    __DSB();
    __NOP(); __NOP(); __NOP(); __NOP();
}

uint32_t ReadRegData32(uint16_t usIndex)
{
    uint32_t ulReturnData = 0;
    volatile uint16_t usMsb, usLsb;
    volatile uint16_t usTemp;

    *(volatile uint16_t*)ADDR_RD_CMD_PORT = (uint16_t)usIndex;
    usTemp = *(volatile uint16_t*)ADDR_RD_CMD_PORT;
    usTemp = *(volatile uint16_t*)ADDR_RD_CMD_PORT;
    if(usTemp != usIndex)
        usTemp = *(volatile uint16_t*)ADDR_RD_CMD_PORT;

    usLsb = *(volatile uint16_t*)ADDR_LSB_RD_DATA_PORT;
    usLsb = *(volatile uint16_t*)ADDR_LSB_RD_DATA_PORT;
    usMsb = *(volatile uint16_t*)ADDR_MSB_RD_DATA_PORT;

    ulReturnData = ((uint32_t)usMsb << 16) | (uint32_t)usLsb;
    return ulReturnData;
}

uint32_t StatusSet_ActualPosition(uint8_t usChNo, int32_t ActPos)
{
    WriteRegData32(CMD_INDEX_COUNTER_DATA(usChNo), (uint32_t)ActPos);
    return DRV_CT_RT_SUCCESS;
}

uint32_t StatusGet_ActualPosition(uint8_t usChNo, int32_t *pActPos)
{
    volatile uint16_t usLsb = *(volatile uint16_t*)ADDR_DIRECT_ENC_LSB(usChNo);
    volatile uint16_t usMsb = *(volatile uint16_t*)ADDR_DIRECT_ENC_MSB(usChNo);
    *pActPos = (int32_t)(((uint32_t)usMsb << 16) | (uint32_t)usLsb);
    return DRV_CT_RT_SUCCESS;
}

uint16_t ReadVendorId16(void)
{
    return *(volatile uint16_t*)ADDR_VENDOR_ID;
}

/*
uint32_t StatusGet_ActualPosition(uint8_t usChNo, int32_t *pActPos)
{
    *pActPos = ReadRegData32(CMD_INDEX_COUNTER_DATA(usChNo));
    return DRV_CT_RT_SUCCESS;
}
*/

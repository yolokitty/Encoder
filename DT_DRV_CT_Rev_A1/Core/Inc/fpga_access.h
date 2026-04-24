/*
 * fpga_access.h
 *
 *  Created on: Jun 7, 2024
 *      Author: Andy KIM
 */

//#ifndef USER_INC_FPGA_ACCESS_H_
//#define USER_INC_FPGA_ACCESS_H_
#include "stm32h7xx_hal.h"

enum {
    DRV_CT_RT_SUCCESS                  = 0,
    DRV_CT_RT_INVALID_RESOURCE         = 1,

    DRV_CT_RT_INVALID_TARGET          = 110,
};

// Define for FPGA////////////////////////////////////////////////////////////////////
#define FPGA_BASE_ADDR      (uint32_t)0x68000000	// Bank1 sub #3
//////////////////////////////////////////////////////////////////////////////////////
// Address Map(aspect to MCU address bus[15:0])
//  0x6EE0  : PRODUCT_VENDOR
//  0x6EE2  : PRODUCT_ID
//  0x6EE4  : PRODUCT_VER_MSB
//  0x6EE8  : PRODUCT_VER_LSB
//  0x7FF2  : read result data register LSB
//  0x7FF4  : read result data register MSB
//  0x7FF6  : write data register LSB
//  0x7FF8  : write data register MSB
//  0x7FFA  : Read cmd port.
//  0x7FFF  : with :1A5A" ==> soft reset
#define ADDR_VENDOR_ID         ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x6EE0))
#define ADDR_PRODUCT_ID        ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x6EE2))
#define ADDR_VERSION_INFO_MSB  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x6EE4))
#define ADDR_VERSION_INFO_LSB  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x6EE8))
#define ADDR_LSB_RD_DATA_PORT  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x7FF2))
#define ADDR_MSB_RD_DATA_PORT  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x7FF4))
#define ADDR_LSB_WR_PORT_DATA  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x7FF6))
#define ADDR_MSB_WR_PORT_DATA  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x7FF8))
#define ADDR_RD_CMD_PORT       ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x7F0A))
#define ADDR_WR_CMD_PORT       ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x7F8C))

#define ADDR_COUNTER_CONFIG(index)    ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x0100 + (0x2 * index)))

#define CMD_INDEX_COUNTER_DATA(index)	(0x0500 + (0x2 * index))
#define CMD_INDEX_DELTA_SIGMA(index)	(0x0220 + (0x2 * index))

#define CMD_INDEX_SPI_DATA	    0x0320

#define ADDR_DIRECT_ENC_LSB(ch)  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x0520 + (0x4 * ch)))
#define ADDR_DIRECT_ENC_MSB(ch)  ((uint32_t)FPGA_BASE_ADDR + (uint32_t)(0x0522 + (0x4 * ch)))

extern void WriteRegData32(uint16_t usIndex, uint32_t ulData);
extern uint32_t ReadRegData32(uint16_t usIndex);
extern uint16_t ReadVendorId16(void);

extern uint32_t StatusSet_ActualPosition(uint8_t usChNo, int32_t ActPos);
extern uint32_t StatusGet_ActualPosition(uint8_t usChNo, int32_t *pActPos);


//#endif /* USER_INC_FPGA_ACCESS_H_ */

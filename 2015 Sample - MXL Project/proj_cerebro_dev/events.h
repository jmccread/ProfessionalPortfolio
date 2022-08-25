/******************************************
 *  ____    ____   ____  ____   _____     *	
 * |_   \  /   _| |_  _||_  _| |_   _|    *
 *   |   \/   |     \ \  / /     | |      *
 *   | |\  /| |      > `' <      | |   _  *
 *  _| |_\/_| |_   _/ /'`\ \_   _| |__/ | *	
 * |_____||_____| |____||____| |________| *	
 *                                        *	
 ******************************************/
 
/**
 * author: 	Joshua McCready 
 * email:	jmccread@umich.edu
 * date:	07/01/2014
 */
 

/******************************************************************************
*
* events.h
* Defines all OS events for Salvo
*
******************************************************************************/
#define RSRC_SD_CARD_P            OSECBP(1) // Resource: SD Card
#define COLLECT_LOW_F_P           OSECBP(2) // Trigger log to log data to SD
#define NEW_HIGH_F_P              OSECBP(3) // New high frequency sample taken 
#define NEW_LOW_F_P               OSECBP(4) // New low frequency sample taken
#define CHECK_ERROR_P             OSECBP(5) // Do error checking periodically 
#define LOG_LOW_F_P               OSECBP(6) // New low frequency sample taken
#define LOG_HIGH_F_P              OSECBP(7) // New high frequency sample taken 
#define TEMP_CHECK_P              OSECBP(8) // Check temperature for heater control
#define ALT_THRESH_P              OSECBP(9) // Initialize burn wire

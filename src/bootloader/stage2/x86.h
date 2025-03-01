#pragma once
#include "stdint.h"

void _cdecl x86_Video_WriteCharTeletype(char c, uint8_t page); 
// We dont include the underscore in the function name because we are using cdecl calling convention
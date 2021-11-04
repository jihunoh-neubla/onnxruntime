/*++

Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the MIT License.

Module Name:

    DepthwiseQConvKernelSize9Neon.asm

Abstract:

    This module implements the routine for the depthwise convolution
    operation with symmetrically quantized integer values for kernel
    size 9. ie, 3x3, 1x9, 9x1

--*/

#include "kxarm64.h"

//
// Stack frame layout for the depthwise conv kernel.
// d8-d15, x19-x30 need to be preserved if used
//

#define  ConvSymDepthwisePostProcessParams_Bias            0
#define  ConvSymDepthwisePostProcessParams_Scale           8
#define  ConvSymDepthwisePostProcessParams_Min             16
#define  ConvSymDepthwisePostProcessParams_Max             20
#define  ConvSymDepthwisePostProcessParams_ZeroPoint       24

#define  MLAS_CONV_SYM_FLAG_INPUT_DIRECT_BIT_INDEX         0
#define  MLAS_CONV_SYM_FLAG_PER_CHANNEL_SCALE_BIT_INDEX    1

#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_x19_x20  0
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_x21_x22  16
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_x23_x24  32
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_x25_x26  48
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_x27_x28  64
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_d8_d9    80
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_d10_d11  96
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_d12_d13  112
#define  MlasConvSymDepthwiseS8S8KernelSize9_backup_d14_d15  128
#define  MlasConvSymDepthwiseS8S8KernelSize9_SavedRegisters  144
#define  MlasConvSymDepthwiseS8S8KernelSize9_SavedRegisters_Neg -144


        TEXTAREA

/*++

Routine Description:

    This routine is the inner kernel to compute a depthwise quantized convolution
    on kernel size 9.

Arguments:

    Input (x0) - Supplies the address of the indirection buffer.
 
    Filter (x1) - Supplies the address of the filter buffer.

    Channels (x2) - Supplies the number of input and output channels.

    Output (x3) - Supplies the address of the output buffer.

    OutputCount (x4)- Supplies the number of image pixels.
  
    PostProcessParams (x5) - Supplies the address of the post process parameter block.
 
    KernelFlags (x6) - Supplies additional flags controlling the operation.

Return Value:

    None.

--*/

        NESTED_ENTRY MlasConvSymDepthwiseS8S8KernelSize9Arm64
        
        PROLOG_SAVE_REG_PAIR      x19, x20, #MlasConvSymDepthwiseS8S8KernelSize9_SavedRegisters_Neg !
        PROLOG_SAVE_REG_PAIR      x21, x22, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x21_x22
        PROLOG_SAVE_REG_PAIR      x23, x24, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x23_x24
        PROLOG_SAVE_REG_PAIR      x25, x26, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x25_x26
        PROLOG_SAVE_REG_PAIR      x27, x28, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x27_x28
        PROLOG_SAVE_REG_PAIR      d8, d9, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d8_d9
        PROLOG_SAVE_REG_PAIR      d10, d11, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d10_d11
        PROLOG_SAVE_REG_PAIR      d12, d13, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d12_d13
        PROLOG_SAVE_REG_PAIR      d14, d15, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d14_d15

        ldr     x7, [x5, #ConvSymDepthwisePostProcessParams_Bias]
        ldr     x8, [x5, #ConvSymDepthwisePostProcessParams_Scale]
        ldr     s0, [x5, #ConvSymDepthwisePostProcessParams_ZeroPoint]
        ins     v12.d[0], x1            // Filter
        ins     v13.d[0], x7            // Bias
        ins     v13.d[1], x8            // Scale
        dup     v0.8h, v0.h[0]          // v0.8h <--- vector for output zero point

        tbnz    x6, MLAS_CONV_SYM_FLAG_PER_CHANNEL_SCALE_BIT_INDEX, MlasConvSymDepthwiseS8S8KernelSize9_SkipPerTensorScaleInit
        ldr     x9, [x5, #ConvSymDepthwisePostProcessParams_Scale]
        ldr     s1, [x9]               // load scale val
        dup     v1.4s, v1.s[0]
        mov     v2.16b, v1.16b
        mov     v3.16b, v1.16b
        mov     v4.16b, v1.16b

MlasConvSymDepthwiseS8S8KernelSize9_SkipPerTensorScaleInit

        add     x9, x3, x2              // x9 <---- Ouput1
        cbz     x4, MlasConvSymDepthwiseS8S8KernelSize9_Exit

MlasConvSymDepthwiseS8S8KernelSize9_OutputLoop
        ldp     x20, x21, [x0], #72     // input ptrs for Output0
        ldp     x22, x23, [x0, #-56]
        sub     x4, x4, #1
        ldp     x24, x25, [x0, #-40]
        ldp     x26, x27, [x0, #-24]
        ldur    x28, [x0, #-8]
        
        cbz     x4, MlasConvSymDepthwiseS8S8KernelSize9_Dup_Inputs
        ldp     x10, x11, [x0], #72     // input ptrs for Output0
        ldp     x12, x13, [x0, #-56]
        sub     x4, x4, #1
        ldp     x14, x15, [x0, #-40]
        ldp     x16, x17, [x0, #-24]
        ldur    x19, [x0, #-8]
        b       MlasConvSymDepthwiseS8S8KernelSize9_Loaded_Input

MlasConvSymDepthwiseS8S8KernelSize9_Dup_Inputs
        mov     x9, x3                  // Output1 <-- Output0
        mov     x10, x20
        mov     x11, x21
        mov     x12, x22
        mov     x13, x23
        mov     x14, x24
        mov     x15, x25
        mov     x16, x26
        mov     x17, x27
        mov     x19, x28

MlasConvSymDepthwiseS8S8KernelSize9_Loaded_Input

        eor     x8, x8, x8              // Processed channels
        umov    x1, v12.D[0]            // filter
        umov    x5, v13.D[0]            // bias
        umov    x7, v13.D[1]            // scale
    
        cmp     x8, x2                  // Save one register by not using count down to zero here
        bhs     MlasConvSymDepthwiseS8S8KernelSize9_Finish_Channels16_Loop

MlasConvSymDepthwiseS8S8KernelSize9_Channels16_Loop
        ldr     q10, [x1]               // vk0
        ldr     q16, [x20, x8]          // out0 vi0
        ldr     q17, [x10, x8]          // out1 vi0
        ldp     q6, q7, [x5], #64       // bias vacc 0-7 for outs
        ldr     q11, [x1, x2]           // vk1
        ldr     q18, [x21, x8]          // out0 vi1
        ldr     q19, [x11, x8]          // out1 vi1
        add     x1, x1, x2, LSL #1
        ldp     q8, q9, [x5, #-32]      // bias vacc 8-15  for outs

        smull   v24.8h, v10.8b, v16.8b
        smull2  v25.8h, v10.16b, v16.16b
        smull   v26.8h, v10.8b, v17.8b
        smull2  v27.8h, v10.16b, v17.16b
        smull   v28.8h, v11.8b, v18.8b
        smull2  v29.8h, v11.16b, v18.16b
        smull   v30.8h, v11.8b, v19.8b
        smull2  v31.8h, v11.16b, v19.16b

        ldr     q14, [x1]               // vk2
        ldr     q20, [x22, x8]          // out0 vi2
        ldr     q21, [x12, x8]          // out1 vi2
        ldr     q15, [x1, x2]           // vk3
        ldr     q22, [x23, x8]          // out0 vi3
        ldr     q23, [x13, x8]          // out1 vi3
        add     x1, x1, x2, LSL #1
        smlal   v24.8h, v14.8b, v20.8b
        smlal2  v25.8h, v14.16b, v20.16b
        smlal   v26.8h, v14.8b, v21.8b
        smlal2  v27.8h, v14.16b, v21.16b
        smlal   v28.8h, v15.8b, v22.8b
        smlal2  v29.8h, v15.16b, v22.16b
        smlal   v30.8h, v15.8b, v23.8b
        smlal2  v31.8h, v15.16b, v23.16b

        saddw   v16.4s, v6.4s, v24.4h   // dup acc for out1
        saddw2  v17.4s, v7.4s, v24.8h
        saddw   v18.4s, v8.4s, v25.4h
        saddw2  v19.4s, v9.4s, v25.8h

        saddw   v6.4s, v6.4s, v26.4h
        saddw2  v7.4s, v7.4s, v26.8h
        saddw   v8.4s, v8.4s, v27.4h
        saddw2  v9.4s, v9.4s, v27.8h

        saddw   v16.4s, v16.4s, v28.4h
        saddw2  v17.4s, v17.4s, v28.8h
        saddw   v18.4s, v18.4s, v29.4h
        saddw2  v19.4s, v19.4s, v29.8h

        ldr     q10, [x1]               // vk4
        ldr     q20, [x24, x8]          // out0 vi4
        ldr     q21, [x14, x8]          // out1 vi4
        ldr     q11, [x1, x2]           // vk5
        ldr     q22, [x25, x8]          // out0 vi5
        ldr     q23, [x15, x8]          // out1 vi5
        add     x1, x1, x2, LSL #1
        saddw   v6.4s, v6.4s, v30.4h
        saddw2  v7.4s, v7.4s, v30.8h
        saddw   v8.4s, v8.4s, v31.4h
        saddw2  v9.4s, v9.4s, v31.8h

        smull   v24.8h, v10.8b, v20.8b
        smull2  v25.8h, v10.16b, v20.16b
        smull   v26.8h, v10.8b, v21.8b
        smull2  v27.8h, v10.16b, v21.16b
        smull   v28.8h, v11.8b, v22.8b
        smull2  v29.8h, v11.16b, v22.16b
        smull   v30.8h, v11.8b, v23.8b
        smull2  v31.8h, v11.16b, v23.16b

        ldr     q14, [x1]               // vk6
        ldr     q20, [x26, x8]          // out0 vi6
        ldr     q21, [x16, x8]          // out1 vi6
        ldr     q14, [x1, x2]           // vk7
        ldr     q22, [x27, x8]          // out0 vi7
        ldr     q23, [x17, x8]          // out1 vi7
        add     x1, x1, x2, LSL #1
        
        smlal   v24.8h, v14.8b, v20.8b
        smlal2  v25.8h, v14.16b, v20.16b
        smlal   v26.8h, v14.8b, v21.8b
        smlal2  v27.8h, v14.16b, v21.16b
        smlal   v28.8h, v15.8b, v22.8b
        smlal2  v29.8h, v15.16b, v22.16b
        smlal   v30.8h, v15.8b, v23.8b
        smlal2  v31.8h, v15.16b, v23.16b

        saddw   v16.4s, v16.4s, v24.4h
        saddw2  v17.4s, v17.4s, v24.8h
        saddw   v18.4s, v18.4s, v25.4h
        saddw2  v19.4s, v19.4s, v25.8h

        saddw   v6.4s, v6.4s, v26.4h
        saddw2  v7.4s, v7.4s, v26.8h
        saddw   v8.4s, v8.4s, v27.4h
        saddw2  v9.4s, v9.4s, v27.8h

        ldr     q10, [x1, x2]           // vk8
        ldr     q20, [x28, x8]          // out0 vi8
        ldr     q21, [x19, x8]          // out1 vi8

        tbz     x6, #MLAS_CONV_SYM_FLAG_PER_CHANNEL_SCALE_BIT_INDEX, DonePerChannelScaleLoad_MlasConvSymDepthwiseS8S8KernelSize9
        ldp     q1, q2, [x7], #64     // scale 0-7 for outs
        ldp     q3, q4, [x7, #-32]    // scale 8-15 for outs

DonePerChannelScaleLoad_MlasConvSymDepthwiseS8S8KernelSize9
        saddw   v16.4s, v16.4s, v28.4h
        saddw2  v17.4s, v17.4s, v28.8h
        saddw   v18.4s, v18.4s, v29.4h
        saddw2  v19.4s, v19.4s, v29.8h

        saddw   v6.4s, v6.4s, v30.4h
        saddw2  v7.4s, v7.4s, v30.8h
        saddw   v8.4s, v8.4s, v31.4h
        saddw2  v9.4s, v9.4s, v31.8h

        smull   v24.8h, v10.8b, v20.8b
        smull2  v25.8h, v10.16b, v20.16b
        smull   v26.8h, v10.8b, v21.8b
        smull2  v27.8h, v10.16b, v21.16b

        saddw   v16.4s, v16.4s, v24.4h
        saddw2  v17.4s, v17.4s, v24.8h
        saddw   v18.4s, v18.4s, v25.4h
        saddw2  v19.4s, v19.4s, v25.8h

        saddw   v6.4s, v6.4s, v26.4h
        saddw2  v7.4s, v7.4s, v26.8h
        saddw   v8.4s, v8.4s, v27.4h
        saddw2  v9.4s, v9.4s, v27.8h

        // Requantize
        scvtf    v16.4s, v16.4s
        scvtf    v17.4s, v17.4s
        scvtf    v18.4s, v18.4s
        scvtf    v19.4s, v19.4s
        scvtf    v6.4s, v6.4s
        scvtf    v7.4s, v7.4s
        scvtf    v8.4s, v8.4s
        scvtf    v9.4s, v9.4s

        fmul     v16.4s, v16.4s, v1.4s
        fmul     v17.4s, v17.4s, v2.4s
        fmul     v18.4s, v18.4s, v3.4s
        fmul     v19.4s, v19.4s, v4.4s
        fmul     v6.4s, v6.4s, v1.4s
        fmul     v7.4s, v7.4s, v2.4s
        fmul     v8.4s, v8.4s, v3.4s
        fmul     v9.4s, v9.4s, v4.4s

        fcvtns  v16.4s, v16.4s
        fcvtns  v17.4s, v17.4s
        fcvtns  v18.4s, v18.4s
        fcvtns  v19.4s, v19.4s
        fcvtns  v6.4s, v6.4s
        fcvtns  v7.4s, v7.4s
        fcvtns  v8.4s, v8.4s
        fcvtns  v9.4s, v9.4s

        // +zp, narrow and combine
        sqxtn   v16.4h, v16.4s
        sqxtn   v18.4h, v18.4s
        sqxtn   v6.4h, v6.4s
        sqxtn   v8.4h, v8.4s
        sqxtn2  v16.8h, v17.4s
        sqxtn2  v18.8h, v19.4s
        sqxtn2  v6.8h, v7.4s
        sqxtn2  v8.8h, v9.4s
        sqadd   v16.8h, v16.8h, v0.8h
        sqadd   v18.8h, v18.8h, v0.8h
        sqadd   v6.8h, v6.8h, v0.8h
        sqadd   v8.8h, v8.8h, v0.8h
        sqxtn   v16.8b, v16.8h
        sqxtn2  v16.16b, v18.8h
        sqxtn   v6.8b, v6.8h
        sqxtn2  v6.16b, v8.8h

        str     q16, [x3, x8]
        str     q6, [x9, x8]
        add     x8, x8, #16
        cmp     x8, x2
        blo     MlasConvSymDepthwiseS8S8KernelSize9_Channels16_Loop

MlasConvSymDepthwiseS8S8KernelSize9_Finish_Channels16_Loop
        add     x3, x3, x2, LSL #1
        add     x9, x9, x2, LSL #1
        cbnz    x4, MlasConvSymDepthwiseS8S8KernelSize9_OutputLoop

MlasConvSymDepthwiseS8S8KernelSize9_Exit
        EPILOG_RESTORE_REG_PAIR      d14, d15, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d14_d15
        EPILOG_RESTORE_REG_PAIR      d12, d13, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d12_d13
        EPILOG_RESTORE_REG_PAIR      d10, d11, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d10_d11
        EPILOG_RESTORE_REG_PAIR      d8, d9, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d8_d9
        EPILOG_RESTORE_REG_PAIR      x27, x28, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x27_x28
        EPILOG_RESTORE_REG_PAIR      x25, x26, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x25_x26
        EPILOG_RESTORE_REG_PAIR      x23, x24, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x23_x24
        EPILOG_RESTORE_REG_PAIR      x21, x22, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x21_x22
        EPILOG_RESTORE_REG_PAIR      x19, x20, #MlasConvSymDepthwiseS8S8KernelSize9_SavedRegisters !
        EPILOG_RETURN

        NESTED_END MlasConvSymDepthwiseS8S8KernelSize9Arm64






        NESTED_ENTRY MlasConvSymDepthwiseU8S8KernelSize9Arm64
        
        PROLOG_SAVE_REG_PAIR      x19, x20, #MlasConvSymDepthwiseS8S8KernelSize9_SavedRegisters_Neg !
        PROLOG_SAVE_REG_PAIR      x21, x22, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x21_x22
        PROLOG_SAVE_REG_PAIR      x23, x24, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x23_x24
        PROLOG_SAVE_REG_PAIR      x25, x26, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x25_x26
        PROLOG_SAVE_REG_PAIR      x27, x28, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x27_x28
        PROLOG_SAVE_REG_PAIR      d8, d9, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d8_d9
        PROLOG_SAVE_REG_PAIR      d10, d11, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d10_d11
        PROLOG_SAVE_REG_PAIR      d12, d13, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d12_d13
        PROLOG_SAVE_REG_PAIR      d14, d15, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d14_d15

        mov     w10, #0x80808080
        ldr     x7, [x5, #ConvSymDepthwisePostProcessParams_Bias]
        ldr     x8, [x5, #ConvSymDepthwisePostProcessParams_Scale]
        ldr     s0, [x5, #ConvSymDepthwisePostProcessParams_ZeroPoint]
        ins     v12.d[0], x1            // Filter
        ins     v13.d[0], x7            // Bias
        ins     v13.d[1], x8            // Scale
        dup     v0.8h, v0.h[0]          // v0.8h <--- vector for output zero point

        tbnz    x6, MLAS_CONV_SYM_FLAG_PER_CHANNEL_SCALE_BIT_INDEX, MlasConvSymDepthwiseU8S8KernelSize9_SkipPerTensorScaleInit
        ldr     x9, [x5, #ConvSymDepthwisePostProcessParams_Scale]
        ldr     s1, [x9]               // load scale val
        dup     v1.4s, v1.s[0]
        mov     v2.16b, v1.16b
        mov     v3.16b, v1.16b
        mov     v4.16b, v1.16b
        dup     v5.4s, w10

MlasConvSymDepthwiseU8S8KernelSize9_SkipPerTensorScaleInit

        add     x9, x3, x2              // x9 <---- Ouput1
        cbz     x4, MlasConvSymDepthwiseU8S8KernelSize9_Exit

MlasConvSymDepthwiseU8S8KernelSize9_OutputLoop
        ldp     x20, x21, [x0], #72     // input ptrs for Output0
        ldp     x22, x23, [x0, #-56]
        sub     x4, x4, #1
        ldp     x24, x25, [x0, #-40]
        ldp     x26, x27, [x0, #-24]
        ldur    x28, [x0, #-8]
        
        cbz     x4, MlasConvSymDepthwiseU8S8KernelSize9_Dup_Inputs
        ldp     x10, x11, [x0], #72     // input ptrs for Output0
        ldp     x12, x13, [x0, #-56]
        sub     x4, x4, #1
        ldp     x14, x15, [x0, #-40]
        ldp     x16, x17, [x0, #-24]
        ldur    x19, [x0, #-8]
        b       MlasConvSymDepthwiseU8S8KernelSize9_Loaded_Input

MlasConvSymDepthwiseU8S8KernelSize9_Dup_Inputs
        mov     x9, x3                  // Output1 <-- Output0
        mov     x10, x20
        mov     x11, x21
        mov     x12, x22
        mov     x13, x23
        mov     x14, x24
        mov     x15, x25
        mov     x16, x26
        mov     x17, x27
        mov     x19, x28

MlasConvSymDepthwiseU8S8KernelSize9_Loaded_Input

        eor     x8, x8, x8              // Processed channels
        umov    x1, v12.D[0]            // filter
        umov    x5, v13.D[0]            // bias
        umov    x7, v13.D[1]            // scale
    
        cmp     x8, x2                  // Save one register by not using count down to zero here
        bhs     MlasConvSymDepthwiseU8S8KernelSize9_Finish_Channels16_Loop

MlasConvSymDepthwiseU8S8KernelSize9_Channels16_Loop
        ldr     q10, [x1]               // vk0
        ldr     q16, [x20, x8]          // out0 vi0
        ldr     q17, [x10, x8]          // out1 vi0
        ldp     q6, q7, [x5], #64       // bias vacc 0-7 for outs
        ldr     q11, [x1, x2]           // vk1
        ldr     q18, [x21, x8]          // out0 vi1
        ldr     q19, [x11, x8]          // out1 vi1
        add     x1, x1, x2, LSL #1
        eor     v16.16b, v16.16b, v5.16b
        eor     v17.16b, v17.16b, v5.16b
        eor     v18.16b, v18.16b, v5.16b
        eor     v19.16b, v19.16b, v5.16b
        ldp     q8, q9, [x5, #-32]      // bias vacc 8-15  for outs

        smull   v24.8h, v10.8b, v16.8b
        smull2  v25.8h, v10.16b, v16.16b
        smull   v26.8h, v10.8b, v17.8b
        smull2  v27.8h, v10.16b, v17.16b
        smull   v28.8h, v11.8b, v18.8b
        smull2  v29.8h, v11.16b, v18.16b
        smull   v30.8h, v11.8b, v19.8b
        smull2  v31.8h, v11.16b, v19.16b

        ldr     q14, [x1]               // vk2
        ldr     q20, [x22, x8]          // out0 vi2
        ldr     q21, [x12, x8]          // out1 vi2
        ldr     q15, [x1, x2]           // vk3
        ldr     q22, [x23, x8]          // out0 vi3
        ldr     q23, [x13, x8]          // out1 vi3
        eor     v20.16b, v20.16b, v5.16b        // -128 to signed int8
        eor     v21.16b, v21.16b, v5.16b
        eor     v22.16b, v22.16b, v5.16b
        eor     v23.16b, v23.16b, v5.16b
        add     x1, x1, x2, LSL #1

        smlal   v24.8h, v14.8b, v20.8b
        smlal2  v25.8h, v14.16b, v20.16b
        smlal   v26.8h, v14.8b, v21.8b
        smlal2  v27.8h, v14.16b, v21.16b
        smlal   v28.8h, v15.8b, v22.8b
        smlal2  v29.8h, v15.16b, v22.16b
        smlal   v30.8h, v15.8b, v23.8b
        smlal2  v31.8h, v15.16b, v23.16b

        saddw   v16.4s, v6.4s, v24.4h   // dup acc for out1
        saddw2  v17.4s, v7.4s, v24.8h
        saddw   v18.4s, v8.4s, v25.4h
        saddw2  v19.4s, v9.4s, v25.8h

        saddw   v6.4s, v6.4s, v26.4h
        saddw2  v7.4s, v7.4s, v26.8h
        saddw   v8.4s, v8.4s, v27.4h
        saddw2  v9.4s, v9.4s, v27.8h

        saddw   v16.4s, v16.4s, v28.4h
        saddw2  v17.4s, v17.4s, v28.8h
        saddw   v18.4s, v18.4s, v29.4h
        saddw2  v19.4s, v19.4s, v29.8h

        ldr     q10, [x1]               // vk4
        ldr     q20, [x24, x8]          // out0 vi4
        ldr     q21, [x14, x8]          // out1 vi4
        ldr     q11, [x1, x2]           // vk5
        ldr     q22, [x25, x8]          // out0 vi5
        ldr     q23, [x15, x8]          // out1 vi5
        add     x1, x1, x2, LSL #1

        saddw   v6.4s, v6.4s, v30.4h
        saddw2  v7.4s, v7.4s, v30.8h
        eor     v20.16b, v20.16b, v5.16b
        eor     v21.16b, v21.16b, v5.16b
        eor     v22.16b, v22.16b, v5.16b
        eor     v23.16b, v23.16b, v5.16b
        saddw   v8.4s, v8.4s, v31.4h
        saddw2  v9.4s, v9.4s, v31.8h

        smull   v24.8h, v10.8b, v20.8b
        smull2  v25.8h, v10.16b, v20.16b
        smull   v26.8h, v10.8b, v21.8b
        smull2  v27.8h, v10.16b, v21.16b
        smull   v28.8h, v11.8b, v22.8b
        smull2  v29.8h, v11.16b, v22.16b
        smull   v30.8h, v11.8b, v23.8b
        smull2  v31.8h, v11.16b, v23.16b

        ldr     q14, [x1]               // vk6
        ldr     q20, [x26, x8]          // out0 vi6
        ldr     q21, [x16, x8]          // out1 vi6
        ldr     q14, [x1, x2]           // vk7
        ldr     q22, [x27, x8]          // out0 vi7
        ldr     q23, [x17, x8]          // out1 vi7
        eor     v20.16b, v20.16b, v5.16b
        eor     v21.16b, v21.16b, v5.16b
        eor     v22.16b, v22.16b, v5.16b
        eor     v23.16b, v23.16b, v5.16b
        add     x1, x1, x2, LSL #1
        
        smlal   v24.8h, v14.8b, v20.8b
        smlal2  v25.8h, v14.16b, v20.16b
        smlal   v26.8h, v14.8b, v21.8b
        smlal2  v27.8h, v14.16b, v21.16b
        smlal   v28.8h, v15.8b, v22.8b
        smlal2  v29.8h, v15.16b, v22.16b
        smlal   v30.8h, v15.8b, v23.8b
        smlal2  v31.8h, v15.16b, v23.16b

        saddw   v16.4s, v16.4s, v24.4h
        saddw2  v17.4s, v17.4s, v24.8h
        saddw   v18.4s, v18.4s, v25.4h
        saddw2  v19.4s, v19.4s, v25.8h

        saddw   v6.4s, v6.4s, v26.4h
        saddw2  v7.4s, v7.4s, v26.8h
        saddw   v8.4s, v8.4s, v27.4h
        saddw2  v9.4s, v9.4s, v27.8h

        ldr     q10, [x1, x2]           // vk8
        ldr     q20, [x28, x8]          // out0 vi8
        ldr     q21, [x19, x8]          // out1 vi8

        tbz     x6, #MLAS_CONV_SYM_FLAG_PER_CHANNEL_SCALE_BIT_INDEX, DonePerChannelScaleLoad_MlasConvSymDepthwiseU8S8KernelSize9
        ldp     q1, q2, [x7], #64     // scale 0-7 for outs
        ldp     q3, q4, [x7, #-32]    // scale 8-15 for outs

DonePerChannelScaleLoad_MlasConvSymDepthwiseU8S8KernelSize9
        saddw   v16.4s, v16.4s, v28.4h
        saddw2  v17.4s, v17.4s, v28.8h
        eor     v20.16b, v20.16b, v5.16b
        eor     v21.16b, v21.16b, v5.16b
        saddw   v18.4s, v18.4s, v29.4h
        saddw2  v19.4s, v19.4s, v29.8h

        saddw   v6.4s, v6.4s, v30.4h
        saddw2  v7.4s, v7.4s, v30.8h
        saddw   v8.4s, v8.4s, v31.4h
        saddw2  v9.4s, v9.4s, v31.8h

        smull   v24.8h, v10.8b, v20.8b
        smull2  v25.8h, v10.16b, v20.16b
        smull   v26.8h, v10.8b, v21.8b
        smull2  v27.8h, v10.16b, v21.16b

        saddw   v16.4s, v16.4s, v24.4h
        saddw2  v17.4s, v17.4s, v24.8h
        saddw   v18.4s, v18.4s, v25.4h
        saddw2  v19.4s, v19.4s, v25.8h

        saddw   v6.4s, v6.4s, v26.4h
        saddw2  v7.4s, v7.4s, v26.8h
        saddw   v8.4s, v8.4s, v27.4h
        saddw2  v9.4s, v9.4s, v27.8h

        // Requantize
        scvtf    v16.4s, v16.4s
        scvtf    v17.4s, v17.4s
        scvtf    v18.4s, v18.4s
        scvtf    v19.4s, v19.4s
        scvtf    v6.4s, v6.4s
        scvtf    v7.4s, v7.4s
        scvtf    v8.4s, v8.4s
        scvtf    v9.4s, v9.4s

        fmul     v16.4s, v16.4s, v1.4s
        fmul     v17.4s, v17.4s, v2.4s
        fmul     v18.4s, v18.4s, v3.4s
        fmul     v19.4s, v19.4s, v4.4s
        fmul     v6.4s, v6.4s, v1.4s
        fmul     v7.4s, v7.4s, v2.4s
        fmul     v8.4s, v8.4s, v3.4s
        fmul     v9.4s, v9.4s, v4.4s

        fcvtns  v16.4s, v16.4s
        fcvtns  v17.4s, v17.4s
        fcvtns  v18.4s, v18.4s
        fcvtns  v19.4s, v19.4s
        fcvtns  v6.4s, v6.4s
        fcvtns  v7.4s, v7.4s
        fcvtns  v8.4s, v8.4s
        fcvtns  v9.4s, v9.4s

        // +zp, narrow and combine
        sqxtn   v16.4h, v16.4s
        sqxtn   v18.4h, v18.4s
        sqxtn   v6.4h, v6.4s
        sqxtn   v8.4h, v8.4s
        sqxtn2  v16.8h, v17.4s
        sqxtn2  v18.8h, v19.4s
        sqxtn2  v6.8h, v7.4s
        sqxtn2  v8.8h, v9.4s
        sqadd   v16.8h, v16.8h, v0.8h
        sqadd   v18.8h, v18.8h, v0.8h
        sqadd   v6.8h, v6.8h, v0.8h
        sqadd   v8.8h, v8.8h, v0.8h
        sqxtn   v16.8b, v16.8h
        sqxtn2  v16.16b, v18.8h
        sqxtn   v6.8b, v6.8h
        sqxtn2  v6.16b, v8.8h

        str     q16, [x3, x8]
        str     q6, [x9, x8]
        add     x8, x8, #16
        cmp     x8, x2
        blo     MlasConvSymDepthwiseU8S8KernelSize9_Channels16_Loop

MlasConvSymDepthwiseU8S8KernelSize9_Finish_Channels16_Loop
        add     x3, x3, x2, LSL #1
        add     x9, x9, x2, LSL #1
        cbnz    x4, MlasConvSymDepthwiseU8S8KernelSize9_OutputLoop

MlasConvSymDepthwiseU8S8KernelSize9_Exit
        EPILOG_RESTORE_REG_PAIR      d14, d15, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d14_d15
        EPILOG_RESTORE_REG_PAIR      d12, d13, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d12_d13
        EPILOG_RESTORE_REG_PAIR      d10, d11, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d10_d11
        EPILOG_RESTORE_REG_PAIR      d8, d9, #MlasConvSymDepthwiseS8S8KernelSize9_backup_d8_d9
        EPILOG_RESTORE_REG_PAIR      x27, x28, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x27_x28
        EPILOG_RESTORE_REG_PAIR      x25, x26, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x25_x26
        EPILOG_RESTORE_REG_PAIR      x23, x24, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x23_x24
        EPILOG_RESTORE_REG_PAIR      x21, x22, #MlasConvSymDepthwiseS8S8KernelSize9_backup_x21_x22
        EPILOG_RESTORE_REG_PAIR      x19, x20, #MlasConvSymDepthwiseS8S8KernelSize9_SavedRegisters !
        EPILOG_RETURN

        NESTED_END MlasConvSymDepthwiseU8S8KernelSize9Arm64


        END
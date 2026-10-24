.class public Lorg/godotengine/godot/input/GodotInputHandler;
.super Ljava/lang/Object;
.source "GodotInputHandler.java"

# interfaces
.implements Landroid/hardware/input/InputManager$InputDeviceListener;
.implements Landroid/hardware/SensorEventListener;


# static fields
.field private static final JOYPAD_IGNORE_LIST:[Ljava/lang/String;

.field private static final ROTARY_INPUT_HORIZONTAL_AXIS:I = 0x0

.field private static final ROTARY_INPUT_VERTICAL_AXIS:I = 0x1

.field private static final TAG:Ljava/lang/String;


# instance fields
.field private cachedRotation:I

.field private final gestureDetector:Landroid/view/GestureDetector;

.field private final godot:Lorg/godotengine/godot/Godot;

.field private final godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

.field private hasHardwareKeyboardConfig:Z

.field private lastSeenToolType:Ljava/util/concurrent/atomic/AtomicInteger;

.field private final mHardwareKeyboardIds:Ljava/util/HashSet;
    .annotation system Ldalvik/annotation/Signature;
        value = {
            "Ljava/util/HashSet<",
            "Ljava/lang/Integer;",
            ">;"
        }
    .end annotation
.end field

.field private final mInputManager:Landroid/hardware/input/InputManager;

.field private final mJoystickIds:Landroid/util/SparseIntArray;

.field private final mJoysticksDevices:Landroid/util/SparseArray;
    .annotation system Ldalvik/annotation/Signature;
        value = {
            "Landroid/util/SparseArray<",
            "Lorg/godotengine/godot/input/Joystick;",
            ">;"
        }
    .end annotation
.end field

.field private overrideVolumeButtons:Z

.field private rotaryInputAxis:I

.field private final scaleGestureDetector:Landroid/view/ScaleGestureDetector;

.field private final windowManager:Landroid/view/WindowManager;


# direct methods
.method static constructor <clinit>()V
    .registers 3

    .line 69
    const-class v0, Lorg/godotengine/godot/input/GodotInputHandler;

    invoke-virtual {v0}, Ljava/lang/Class;->getSimpleName()Ljava/lang/String;

    move-result-object v0

    sput-object v0, Lorg/godotengine/godot/input/GodotInputHandler;->TAG:Ljava/lang/String;

    .line 74
    const/4 v0, 0x6

    new-array v0, v0, [Ljava/lang/String;

    const/4 v1, 0x0

    const-string v2, "uinput-fpc"

    aput-object v2, v0, v1

    const/4 v1, 0x1

    const-string v2, "uinput-goodix"

    aput-object v2, v0, v1

    const/4 v1, 0x2

    const-string v2, "uinput-synaptics"

    aput-object v2, v0, v1

    const/4 v1, 0x3

    const-string v2, "uinput-elan"

    aput-object v2, v0, v1

    const/4 v1, 0x4

    const-string v2, "uinput-vfs"

    aput-object v2, v0, v1

    const/4 v1, 0x5

    const-string v2, "uinput-atrus"

    aput-object v2, v0, v1

    sput-object v0, Lorg/godotengine/godot/input/GodotInputHandler;->JOYPAD_IGNORE_LIST:[Ljava/lang/String;

    return-void
.end method

.method public constructor <init>(Landroid/content/Context;Lorg/godotengine/godot/Godot;)V
    .registers 7
    .param p1, "context"    # Landroid/content/Context;
    .param p2, "godot"    # Lorg/godotengine/godot/Godot;

    .line 106
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V

    .line 84
    new-instance v0, Landroid/util/SparseIntArray;

    const/4 v1, 0x4

    invoke-direct {v0, v1}, Landroid/util/SparseIntArray;-><init>(I)V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    .line 85
    new-instance v0, Landroid/util/SparseArray;

    invoke-direct {v0, v1}, Landroid/util/SparseArray;-><init>(I)V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoysticksDevices:Landroid/util/SparseArray;

    .line 86
    new-instance v0, Ljava/util/HashSet;

    invoke-direct {v0}, Ljava/util/HashSet;-><init>()V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mHardwareKeyboardIds:Ljava/util/HashSet;

    .line 98
    new-instance v0, Ljava/util/concurrent/atomic/AtomicInteger;

    const/4 v1, 0x0

    invoke-direct {v0, v1}, Ljava/util/concurrent/atomic/AtomicInteger;-><init>(I)V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->lastSeenToolType:Ljava/util/concurrent/atomic/AtomicInteger;

    .line 100
    const/4 v0, 0x1

    iput v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->rotaryInputAxis:I

    .line 102
    const/4 v2, -0x1

    iput v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->cachedRotation:I

    .line 103
    iput-boolean v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->overrideVolumeButtons:Z

    .line 104
    iput-boolean v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->hasHardwareKeyboardConfig:Z

    .line 107
    iput-object p2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godot:Lorg/godotengine/godot/Godot;

    .line 108
    const-string v2, "input"

    invoke-virtual {p1, v2}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Landroid/hardware/input/InputManager;

    iput-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mInputManager:Landroid/hardware/input/InputManager;

    .line 109
    iget-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mInputManager:Landroid/hardware/input/InputManager;

    const/4 v3, 0x0

    invoke-virtual {v2, p0, v3}, Landroid/hardware/input/InputManager;->registerInputDeviceListener(Landroid/hardware/input/InputManager$InputDeviceListener;Landroid/os/Handler;)V

    .line 111
    const-string v2, "window"

    invoke-virtual {p1, v2}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v2

    check-cast v2, Landroid/view/WindowManager;

    iput-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->windowManager:Landroid/view/WindowManager;

    .line 113
    new-instance v2, Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-direct {v2, p0}, Lorg/godotengine/godot/input/GodotGestureHandler;-><init>(Lorg/godotengine/godot/input/GodotInputHandler;)V

    iput-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    .line 114
    new-instance v2, Landroid/view/GestureDetector;

    iget-object v3, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-direct {v2, p1, v3}, Landroid/view/GestureDetector;-><init>(Landroid/content/Context;Landroid/view/GestureDetector$OnGestureListener;)V

    iput-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->gestureDetector:Landroid/view/GestureDetector;

    .line 115
    iget-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->gestureDetector:Landroid/view/GestureDetector;

    invoke-virtual {v2, v1}, Landroid/view/GestureDetector;->setIsLongpressEnabled(Z)V

    .line 116
    new-instance v2, Landroid/view/ScaleGestureDetector;

    iget-object v3, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-direct {v2, p1, v3}, Landroid/view/ScaleGestureDetector;-><init>(Landroid/content/Context;Landroid/view/ScaleGestureDetector$OnScaleGestureListener;)V

    iput-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->scaleGestureDetector:Landroid/view/ScaleGestureDetector;

    .line 117
    iget-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->scaleGestureDetector:Landroid/view/ScaleGestureDetector;

    invoke-virtual {v2, v0}, Landroid/view/ScaleGestureDetector;->setStylusScaleEnabled(Z)V

    .line 118
    invoke-virtual {p1}, Landroid/content/Context;->getResources()Landroid/content/res/Resources;

    move-result-object v2

    invoke-virtual {v2}, Landroid/content/res/Resources;->getConfiguration()Landroid/content/res/Configuration;

    move-result-object v2

    .line 119
    .local v2, "config":Landroid/content/res/Configuration;
    iget v3, v2, Landroid/content/res/Configuration;->keyboard:I

    if-eq v3, v0, :cond_7b

    iget v3, v2, Landroid/content/res/Configuration;->hardKeyboardHidden:I

    if-ne v3, v0, :cond_7b

    move v1, v0

    :cond_7b
    iput-boolean v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->hasHardwareKeyboardConfig:Z

    .line 121
    return-void
.end method

.method private assignJoystickIdNumber(I)I
    .registers 4
    .param p1, "deviceId"    # I

    .line 354
    const/4 v0, 0x0

    .line 355
    .local v0, "godotJoyId":I
    :goto_1
    iget-object v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v1, v0}, Landroid/util/SparseIntArray;->indexOfValue(I)I

    move-result v1

    if-ltz v1, :cond_c

    .line 356
    add-int/lit8 v0, v0, 0x1

    goto :goto_1

    .line 358
    :cond_c
    iget-object v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v1, p1, v0}, Landroid/util/SparseIntArray;->put(II)V

    .line 359
    return v0
.end method

.method private dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V
    .registers 3
    .param p1, "runnable"    # Lorg/godotengine/godot/input/InputEventRunnable;

    .line 790
    invoke-direct {p0}, Lorg/godotengine/godot/input/GodotInputHandler;->shouldDispatchInputToRenderThread()Z

    move-result v0

    if-eqz v0, :cond_c

    .line 791
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godot:Lorg/godotengine/godot/Godot;

    invoke-virtual {v0, p1}, Lorg/godotengine/godot/Godot;->runOnRenderThread(Ljava/lang/Runnable;)V

    goto :goto_f

    .line 793
    :cond_c
    invoke-virtual {p1}, Lorg/godotengine/godot/input/InputEventRunnable;->run()V

    .line 795
    :goto_f
    return-void
.end method

.method static getEventTiltX(Landroid/view/MotionEvent;)F
    .registers 6
    .param p0, "event"    # Landroid/view/MotionEvent;

    .line 576
    invoke-virtual {p0}, Landroid/view/MotionEvent;->getOrientation()F

    move-result v0

    .line 579
    .local v0, "orientation":F
    const/16 v1, 0x19

    invoke-virtual {p0, v1}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v1

    .line 581
    .local v1, "tilt":F
    float-to-double v2, v1

    invoke-static {v2, v3}, Ljava/lang/Math;->sin(D)D

    move-result-wide v2

    double-to-float v2, v2

    .line 584
    .local v2, "tiltMult":F
    float-to-double v3, v0

    invoke-static {v3, v4}, Ljava/lang/Math;->sin(D)D

    move-result-wide v3

    neg-double v3, v3

    double-to-float v3, v3

    mul-float/2addr v3, v2

    return v3
.end method

.method static getEventTiltY(Landroid/view/MotionEvent;)F
    .registers 6
    .param p0, "event"    # Landroid/view/MotionEvent;

    .line 589
    invoke-virtual {p0}, Landroid/view/MotionEvent;->getOrientation()F

    move-result v0

    .line 592
    .local v0, "orientation":F
    const/16 v1, 0x19

    invoke-virtual {p0, v1}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v1

    .line 594
    .local v1, "tilt":F
    float-to-double v2, v1

    invoke-static {v2, v3}, Ljava/lang/Math;->sin(D)D

    move-result-wide v2

    double-to-float v2, v2

    .line 597
    .local v2, "tiltMult":F
    float-to-double v3, v0

    invoke-static {v3, v4}, Ljava/lang/Math;->cos(D)D

    move-result-wide v3

    double-to-float v3, v3

    mul-float/2addr v3, v2

    return v3
.end method

.method static getEventToolType(Landroid/view/MotionEvent;)I
    .registers 3
    .param p0, "event"    # Landroid/view/MotionEvent;

    .line 530
    invoke-virtual {p0}, Landroid/view/MotionEvent;->getPointerCount()I

    move-result v0

    const/4 v1, 0x0

    if-lez v0, :cond_b

    invoke-virtual {p0, v1}, Landroid/view/MotionEvent;->getToolType(I)I

    move-result v1

    :cond_b
    return v1
.end method

.method public static getGodotButton(I)I
    .registers 2
    .param p0, "keyCode"    # I

    .line 458
    sparse-switch p0, :sswitch_data_3e

    .line 523
    add-int/lit16 v0, p0, -0xbc

    add-int/lit8 v0, v0, 0x14

    .local v0, "button":I
    goto :goto_3c

    .line 513
    .end local v0    # "button":I
    :sswitch_8
    const/16 v0, 0xf

    .line 514
    .restart local v0    # "button":I
    goto :goto_3c

    .line 488
    .end local v0    # "button":I
    :sswitch_b
    const/4 v0, 0x5

    .line 489
    .restart local v0    # "button":I
    goto :goto_3c

    .line 498
    .end local v0    # "button":I
    :sswitch_d
    const/16 v0, 0x8

    .line 499
    .restart local v0    # "button":I
    goto :goto_3c

    .line 495
    .end local v0    # "button":I
    :sswitch_10
    const/4 v0, 0x7

    .line 496
    .restart local v0    # "button":I
    goto :goto_3c

    .line 481
    .end local v0    # "button":I
    :sswitch_12
    const/16 v0, 0x10

    .line 482
    .restart local v0    # "button":I
    goto :goto_3c

    .line 475
    .end local v0    # "button":I
    :sswitch_15
    const/16 v0, 0xf

    .line 476
    .restart local v0    # "button":I
    goto :goto_3c

    .line 478
    .end local v0    # "button":I
    :sswitch_18
    const/16 v0, 0xa

    .line 479
    .restart local v0    # "button":I
    goto :goto_3c

    .line 472
    .end local v0    # "button":I
    :sswitch_1b
    const/16 v0, 0x9

    .line 473
    .restart local v0    # "button":I
    goto :goto_3c

    .line 519
    .end local v0    # "button":I
    :sswitch_1e
    const/16 v0, 0x12

    .line 520
    .restart local v0    # "button":I
    goto :goto_3c

    .line 469
    .end local v0    # "button":I
    :sswitch_21
    const/4 v0, 0x3

    .line 470
    .restart local v0    # "button":I
    goto :goto_3c

    .line 466
    .end local v0    # "button":I
    :sswitch_23
    const/4 v0, 0x2

    .line 467
    .restart local v0    # "button":I
    goto :goto_3c

    .line 516
    .end local v0    # "button":I
    :sswitch_25
    const/16 v0, 0x11

    .line 517
    .restart local v0    # "button":I
    goto :goto_3c

    .line 463
    .end local v0    # "button":I
    :sswitch_28
    const/4 v0, 0x1

    .line 464
    .restart local v0    # "button":I
    goto :goto_3c

    .line 460
    .end local v0    # "button":I
    :sswitch_2a
    const/4 v0, 0x0

    .line 461
    .restart local v0    # "button":I
    goto :goto_3c

    .line 492
    .end local v0    # "button":I
    :sswitch_2c
    const/4 v0, 0x6

    .line 493
    .restart local v0    # "button":I
    goto :goto_3c

    .line 510
    .end local v0    # "button":I
    :sswitch_2e
    const/16 v0, 0xe

    .line 511
    .restart local v0    # "button":I
    goto :goto_3c

    .line 507
    .end local v0    # "button":I
    :sswitch_31
    const/16 v0, 0xd

    .line 508
    .restart local v0    # "button":I
    goto :goto_3c

    .line 504
    .end local v0    # "button":I
    :sswitch_34
    const/16 v0, 0xc

    .line 505
    .restart local v0    # "button":I
    goto :goto_3c

    .line 501
    .end local v0    # "button":I
    :sswitch_37
    const/16 v0, 0xb

    .line 502
    .restart local v0    # "button":I
    goto :goto_3c

    .line 485
    .end local v0    # "button":I
    :sswitch_3a
    const/4 v0, 0x4

    .line 486
    .restart local v0    # "button":I
    nop

    .line 526
    :goto_3c
    return v0

    nop

    :sswitch_data_3e
    .sparse-switch
        0x4 -> :sswitch_3a
        0x13 -> :sswitch_37
        0x14 -> :sswitch_34
        0x15 -> :sswitch_31
        0x16 -> :sswitch_2e
        0x52 -> :sswitch_2c
        0x60 -> :sswitch_2a
        0x61 -> :sswitch_28
        0x62 -> :sswitch_25
        0x63 -> :sswitch_23
        0x64 -> :sswitch_21
        0x65 -> :sswitch_1e
        0x66 -> :sswitch_1b
        0x67 -> :sswitch_18
        0x68 -> :sswitch_15
        0x69 -> :sswitch_12
        0x6a -> :sswitch_10
        0x6b -> :sswitch_d
        0x6c -> :sswitch_2c
        0x6d -> :sswitch_3a
        0x6e -> :sswitch_b
        0x82 -> :sswitch_8
    .end sparse-switch
.end method

.method private handleJoystickAxisEvent(IIF)V
    .registers 5
    .param p1, "device"    # I
    .param p2, "axis"    # I
    .param p3, "value"    # F

    .line 750
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v0

    .line 751
    .local v0, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v0, :cond_7

    .line 752
    return-void

    .line 755
    :cond_7
    invoke-virtual {v0, p1, p2, p3}, Lorg/godotengine/godot/input/InputEventRunnable;->setJoystickAxisEvent(IIF)V

    .line 756
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 757
    return-void
.end method

.method private handleJoystickButtonEvent(IIZ)V
    .registers 5
    .param p1, "device"    # I
    .param p2, "button"    # I
    .param p3, "pressed"    # Z

    .line 740
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v0

    .line 741
    .local v0, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v0, :cond_7

    .line 742
    return-void

    .line 745
    :cond_7
    invoke-virtual {v0, p1, p2, p3}, Lorg/godotengine/godot/input/InputEventRunnable;->setJoystickButtonEvent(IIZ)V

    .line 746
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 747
    return-void
.end method

.method private handleJoystickConnectionChangedEvent(IZLjava/lang/String;)V
    .registers 5
    .param p1, "device"    # I
    .param p2, "connected"    # Z
    .param p3, "name"    # Ljava/lang/String;

    .line 770
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v0

    .line 771
    .local v0, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v0, :cond_7

    .line 772
    return-void

    .line 775
    :cond_7
    invoke-virtual {v0, p1, p2, p3}, Lorg/godotengine/godot/input/InputEventRunnable;->setJoystickConnectionChangedEvent(IZLjava/lang/String;)V

    .line 776
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 777
    return-void
.end method

.method private handleJoystickHatEvent(III)V
    .registers 5
    .param p1, "device"    # I
    .param p2, "hatX"    # I
    .param p3, "hatY"    # I

    .line 760
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v0

    .line 761
    .local v0, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v0, :cond_7

    .line 762
    return-void

    .line 765
    :cond_7
    invoke-virtual {v0, p1, p2, p3}, Lorg/godotengine/godot/input/InputEventRunnable;->setJoystickHatEvent(III)V

    .line 766
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 767
    return-void
.end method

.method private isKeyEventGameDevice(I)Z
    .registers 5
    .param p1, "source"    # I

    .line 191
    const/16 v0, 0x301

    const/4 v1, 0x0

    if-ne p1, v0, :cond_6

    .line 192
    return v1

    .line 194
    :cond_6
    const v0, 0x1000010

    and-int v2, p1, v0

    if-eq v2, v0, :cond_19

    and-int/lit16 v0, p1, 0x201

    const/16 v2, 0x201

    if-eq v0, v2, :cond_19

    and-int/lit16 v0, p1, 0x401

    const/16 v2, 0x401

    if-ne v0, v2, :cond_1a

    :cond_19
    const/4 v1, 0x1

    :cond_1a
    return v1
.end method

.method static isMouseEvent(Landroid/view/MotionEvent;)Z
    .registers 8
    .param p0, "event"    # Landroid/view/MotionEvent;

    .line 534
    invoke-static {p0}, Lorg/godotengine/godot/input/GodotInputHandler;->getEventToolType(Landroid/view/MotionEvent;)I

    move-result v0

    .line 535
    .local v0, "toolType":I
    invoke-virtual {p0}, Landroid/view/MotionEvent;->getSource()I

    move-result v1

    .line 537
    .local v1, "eventSource":I
    const/4 v2, 0x1

    const/4 v3, 0x0

    packed-switch v0, :pswitch_data_32

    .line 548
    and-int/lit16 v4, v1, 0x2002

    const/16 v5, 0x2002

    if-eq v4, v5, :cond_1e

    and-int/lit16 v4, v1, 0x5002

    const/16 v5, 0x4002

    if-ne v4, v5, :cond_1c

    goto :goto_1e

    .line 544
    :pswitch_1a
    return v2

    .line 539
    :pswitch_1b
    return v3

    .line 548
    :cond_1c
    move v4, v3

    goto :goto_1f

    :cond_1e
    :goto_1e
    move v4, v2

    .line 551
    .local v4, "mouseSource":Z
    :goto_1f
    sget v5, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v6, 0x1a

    if-lt v5, v6, :cond_31

    .line 552
    if-nez v4, :cond_30

    const v5, 0x20004

    and-int v6, v1, v5

    if-ne v6, v5, :cond_2f

    goto :goto_30

    :cond_2f
    move v2, v3

    :cond_30
    :goto_30
    move v4, v2

    .line 555
    :cond_31
    return v4

    :pswitch_data_32
    .packed-switch 0x1
        :pswitch_1b
        :pswitch_1a
        :pswitch_1a
        :pswitch_1a
    .end packed-switch
.end method

.method private shouldDispatchInputToRenderThread()Z
    .registers 2

    .line 168
    invoke-static {}, Lorg/godotengine/godot/GodotLib;->shouldDispatchInputToRenderThread()Z

    move-result v0

    return v0
.end method

.method private updateCachedRotation()V
    .registers 2

    .line 850
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->windowManager:Landroid/view/WindowManager;

    invoke-interface {v0}, Landroid/view/WindowManager;->getDefaultDisplay()Landroid/view/Display;

    move-result-object v0

    invoke-virtual {v0}, Landroid/view/Display;->getRotation()I

    move-result v0

    iput v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->cachedRotation:I

    .line 851
    return-void
.end method


# virtual methods
.method public canCapturePointer()Z
    .registers 3

    .line 198
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->lastSeenToolType:Ljava/util/concurrent/atomic/AtomicInteger;

    invoke-virtual {v0}, Ljava/util/concurrent/atomic/AtomicInteger;->get()I

    move-result v0

    const/4 v1, 0x3

    if-eq v0, v1, :cond_14

    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->lastSeenToolType:Ljava/util/concurrent/atomic/AtomicInteger;

    .line 199
    invoke-virtual {v0}, Ljava/util/concurrent/atomic/AtomicInteger;->get()I

    move-result v0

    if-nez v0, :cond_12

    goto :goto_14

    :cond_12
    const/4 v0, 0x0

    goto :goto_15

    :cond_14
    :goto_14
    const/4 v0, 0x1

    .line 198
    :goto_15
    return v0
.end method

.method public disableScrollDeadzone(Z)V
    .registers 3
    .param p1, "disable"    # Z

    .line 134
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-virtual {v0, p1}, Lorg/godotengine/godot/input/GodotGestureHandler;->setScrollDeadzoneDisabled(Z)V

    .line 135
    return-void
.end method

.method public enableHapticFeedback(Z)V
    .registers 3
    .param p1, "enable"    # Z

    .line 141
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-virtual {v0, p1}, Lorg/godotengine/godot/input/GodotGestureHandler;->setHapticFeedbackEnabled(Z)V

    .line 142
    return-void
.end method

.method public enableLongPress(Z)V
    .registers 3
    .param p1, "enable"    # Z

    .line 127
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->gestureDetector:Landroid/view/GestureDetector;

    invoke-virtual {v0, p1}, Landroid/view/GestureDetector;->setIsLongpressEnabled(Z)V

    .line 128
    return-void
.end method

.method public enablePanningAndScalingGestures(Z)V
    .registers 3
    .param p1, "enable"    # Z

    .line 160
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-virtual {v0, p1}, Lorg/godotengine/godot/input/GodotGestureHandler;->setPanningAndScalingEnabled(Z)V

    .line 161
    return-void
.end method

.method handleKeyEvent(IIIZZ)V
    .registers 13
    .param p1, "physicalKeycode"    # I
    .param p2, "unicode"    # I
    .param p3, "keyLabel"    # I
    .param p4, "pressed"    # Z
    .param p5, "echo"    # Z

    .line 780
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v6

    .line 781
    .local v6, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v6, :cond_7

    .line 782
    return-void

    .line 785
    :cond_7
    move-object v0, v6

    move v1, p1

    move v2, p2

    move v3, p3

    move v4, p4

    move v5, p5

    invoke-virtual/range {v0 .. v5}, Lorg/godotengine/godot/input/InputEventRunnable;->setKeyEvent(IIIZZ)V

    .line 786
    invoke-direct {p0, v6}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 787
    return-void
.end method

.method handleMagnifyEvent(FFF)V
    .registers 5
    .param p1, "x"    # F
    .param p2, "y"    # F
    .param p3, "factor"    # F

    .line 720
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v0

    .line 721
    .local v0, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v0, :cond_7

    .line 722
    return-void

    .line 725
    :cond_7
    invoke-virtual {v0, p1, p2, p3}, Lorg/godotengine/godot/input/InputEventRunnable;->setMagnifyEvent(FFF)V

    .line 726
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 727
    return-void
.end method

.method handleMotionEvent(Landroid/view/MotionEvent;)Z
    .registers 3
    .param p1, "event"    # Landroid/view/MotionEvent;

    .line 560
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getActionMasked()I

    move-result v0

    invoke-virtual {p0, p1, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMotionEvent(Landroid/view/MotionEvent;I)Z

    move-result v0

    return v0
.end method

.method handleMotionEvent(Landroid/view/MotionEvent;I)Z
    .registers 4
    .param p1, "event"    # Landroid/view/MotionEvent;
    .param p2, "eventActionOverride"    # I

    .line 564
    const/4 v0, 0x0

    invoke-virtual {p0, p1, p2, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMotionEvent(Landroid/view/MotionEvent;IZ)Z

    move-result v0

    return v0
.end method

.method handleMotionEvent(Landroid/view/MotionEvent;IZ)Z
    .registers 5
    .param p1, "event"    # Landroid/view/MotionEvent;
    .param p2, "eventActionOverride"    # I
    .param p3, "doubleTap"    # Z

    .line 568
    invoke-static {p1}, Lorg/godotengine/godot/input/GodotInputHandler;->isMouseEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    if-eqz v0, :cond_b

    .line 569
    invoke-virtual {p0, p1, p2, p3}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(Landroid/view/MotionEvent;IZ)Z

    move-result v0

    return v0

    .line 571
    :cond_b
    invoke-virtual {p0, p1, p2, p3}, Lorg/godotengine/godot/input/GodotInputHandler;->handleTouchEvent(Landroid/view/MotionEvent;IZ)Z

    move-result v0

    return v0
.end method

.method handleMouseEvent(IIFFFFZZFFF)Z
    .registers 26
    .param p1, "eventAction"    # I
    .param p2, "buttonsMask"    # I
    .param p3, "x"    # F
    .param p4, "y"    # F
    .param p5, "deltaX"    # F
    .param p6, "deltaY"    # F
    .param p7, "doubleClick"    # Z
    .param p8, "sourceMouseRelative"    # Z
    .param p9, "pressure"    # F
    .param p10, "tiltX"    # F
    .param p11, "tiltY"    # F

    .line 646
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v12

    .line 647
    .local v12, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    const/4 v0, 0x0

    if-nez v12, :cond_8

    .line 648
    return v0

    .line 652
    :cond_8
    packed-switch p1, :pswitch_data_3a

    goto :goto_14

    .line 656
    :pswitch_c
    const/4 v1, 0x0

    .line 657
    .end local p2    # "buttonsMask":I
    .local v1, "buttonsMask":I
    move v13, v1

    goto :goto_16

    .line 660
    .end local v1    # "buttonsMask":I
    .restart local p2    # "buttonsMask":I
    :pswitch_f
    if-nez p2, :cond_14

    .line 661
    const/4 v1, 0x1

    move v13, v1

    .end local p2    # "buttonsMask":I
    .restart local v1    # "buttonsMask":I
    goto :goto_16

    .line 669
    .end local v1    # "buttonsMask":I
    .restart local p2    # "buttonsMask":I
    :cond_14
    :goto_14
    move/from16 v13, p2

    .end local p2    # "buttonsMask":I
    .local v13, "buttonsMask":I
    :goto_16
    packed-switch p1, :pswitch_data_46

    .line 683
    :pswitch_19
    move-object v1, p0

    return v0

    .line 678
    :pswitch_1b
    move-object v0, v12

    move v1, p1

    move v2, v13

    move/from16 v3, p3

    move/from16 v4, p4

    move/from16 v5, p5

    move/from16 v6, p6

    move/from16 v7, p7

    move/from16 v8, p8

    move/from16 v9, p9

    move/from16 v10, p10

    move/from16 v11, p11

    invoke-virtual/range {v0 .. v11}, Lorg/godotengine/godot/input/InputEventRunnable;->setMouseEvent(IIFFFFZZFFF)V

    .line 679
    move-object v1, p0

    invoke-direct {p0, v12}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 680
    const/4 v0, 0x1

    return v0

    nop

    :pswitch_data_3a
    .packed-switch 0x0
        :pswitch_f
        :pswitch_c
        :pswitch_f
        :pswitch_c
    .end packed-switch

    :pswitch_data_46
    .packed-switch 0x0
        :pswitch_1b
        :pswitch_1b
        :pswitch_1b
        :pswitch_1b
        :pswitch_19
        :pswitch_19
        :pswitch_19
        :pswitch_1b
        :pswitch_1b
        :pswitch_1b
        :pswitch_1b
    .end packed-switch
.end method

.method handleMouseEvent(IZ)Z
    .registers 15
    .param p1, "eventAction"    # I
    .param p2, "sourceMouseRelative"    # Z

    .line 642
    const/4 v10, 0x0

    const/4 v11, 0x0

    const/4 v2, 0x0

    const/4 v3, 0x0

    const/4 v4, 0x0

    const/4 v5, 0x0

    const/4 v6, 0x0

    const/4 v7, 0x0

    const/high16 v9, 0x3f800000    # 1.0f

    move-object v0, p0

    move v1, p1

    move v8, p2

    invoke-virtual/range {v0 .. v11}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(IIFFFFZZFFF)Z

    move-result v0

    return v0
.end method

.method handleMouseEvent(Landroid/view/MotionEvent;)Z
    .registers 3
    .param p1, "event"    # Landroid/view/MotionEvent;

    .line 601
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getActionMasked()I

    move-result v0

    invoke-virtual {p0, p1, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(Landroid/view/MotionEvent;I)Z

    move-result v0

    return v0
.end method

.method handleMouseEvent(Landroid/view/MotionEvent;I)Z
    .registers 4
    .param p1, "event"    # Landroid/view/MotionEvent;
    .param p2, "eventActionOverride"    # I

    .line 605
    const/4 v0, 0x0

    invoke-virtual {p0, p1, p2, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(Landroid/view/MotionEvent;IZ)Z

    move-result v0

    return v0
.end method

.method handleMouseEvent(Landroid/view/MotionEvent;IIZ)Z
    .registers 25
    .param p1, "event"    # Landroid/view/MotionEvent;
    .param p2, "eventActionOverride"    # I
    .param p3, "buttonMaskOverride"    # I
    .param p4, "doubleTap"    # Z

    .line 613
    move-object/from16 v0, p1

    invoke-virtual/range {p1 .. p1}, Landroid/view/MotionEvent;->getX()F

    move-result v13

    .line 614
    .local v13, "x":F
    invoke-virtual/range {p1 .. p1}, Landroid/view/MotionEvent;->getY()F

    move-result v14

    .line 616
    .local v14, "y":F
    invoke-virtual/range {p1 .. p1}, Landroid/view/MotionEvent;->getPressure()F

    move-result v15

    .line 618
    .local v15, "pressure":F
    const/4 v1, 0x0

    .line 619
    .local v1, "verticalFactor":F
    const/4 v2, 0x0

    .line 623
    .local v2, "horizontalFactor":F
    const/high16 v3, 0x400000

    invoke-virtual {v0, v3}, Landroid/view/MotionEvent;->isFromSource(I)Z

    move-result v3

    const/16 v4, 0x1a

    if-eqz v3, :cond_34

    .line 624
    move-object/from16 v12, p0

    iget v3, v12, Lorg/godotengine/godot/input/GodotInputHandler;->rotaryInputAxis:I

    if-nez v3, :cond_2a

    .line 625
    invoke-virtual {v0, v4}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v3

    neg-float v2, v3

    move/from16 v16, v1

    move/from16 v17, v2

    goto :goto_46

    .line 628
    :cond_2a
    invoke-virtual {v0, v4}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v3

    neg-float v1, v3

    move/from16 v16, v1

    move/from16 v17, v2

    goto :goto_46

    .line 631
    :cond_34
    move-object/from16 v12, p0

    const/16 v3, 0x9

    invoke-virtual {v0, v3}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v1

    .line 632
    const/16 v3, 0xa

    invoke-virtual {v0, v3}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v2

    move/from16 v16, v1

    move/from16 v17, v2

    .line 634
    .end local v1    # "verticalFactor":F
    .end local v2    # "horizontalFactor":F
    .local v16, "verticalFactor":F
    .local v17, "horizontalFactor":F
    :goto_46
    const/4 v1, 0x0

    .line 635
    .local v1, "sourceMouseRelative":Z
    sget v2, Landroid/os/Build$VERSION;->SDK_INT:I

    if-lt v2, v4, :cond_55

    .line 636
    const v2, 0x20004

    invoke-virtual {v0, v2}, Landroid/view/MotionEvent;->isFromSource(I)Z

    move-result v1

    move/from16 v18, v1

    goto :goto_57

    .line 635
    :cond_55
    move/from16 v18, v1

    .line 638
    .end local v1    # "sourceMouseRelative":Z
    .local v18, "sourceMouseRelative":Z
    :goto_57
    invoke-static/range {p1 .. p1}, Lorg/godotengine/godot/input/GodotInputHandler;->getEventTiltX(Landroid/view/MotionEvent;)F

    move-result v11

    invoke-static/range {p1 .. p1}, Lorg/godotengine/godot/input/GodotInputHandler;->getEventTiltY(Landroid/view/MotionEvent;)F

    move-result v19

    move-object/from16 v1, p0

    move/from16 v2, p2

    move/from16 v3, p3

    move v4, v13

    move v5, v14

    move/from16 v6, v17

    move/from16 v7, v16

    move/from16 v8, p4

    move/from16 v9, v18

    move v10, v15

    move/from16 v12, v19

    invoke-virtual/range {v1 .. v12}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(IIFFFFZZFFF)Z

    move-result v1

    return v1
.end method

.method handleMouseEvent(Landroid/view/MotionEvent;IZ)Z
    .registers 5
    .param p1, "event"    # Landroid/view/MotionEvent;
    .param p2, "eventActionOverride"    # I
    .param p3, "doubleTap"    # Z

    .line 609
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getButtonState()I

    move-result v0

    invoke-virtual {p0, p1, p2, v0, p3}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(Landroid/view/MotionEvent;IIZ)Z

    move-result v0

    return v0
.end method

.method handlePanEvent(FFFF)V
    .registers 6
    .param p1, "x"    # F
    .param p2, "y"    # F
    .param p3, "deltaX"    # F
    .param p4, "deltaY"    # F

    .line 730
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v0

    .line 731
    .local v0, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v0, :cond_7

    .line 732
    return-void

    .line 735
    :cond_7
    invoke-virtual {v0, p1, p2, p3, p4}, Lorg/godotengine/godot/input/InputEventRunnable;->setPanEvent(FFFF)V

    .line 736
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 737
    return-void
.end method

.method handleTouchEvent(Landroid/view/MotionEvent;)Z
    .registers 3
    .param p1, "event"    # Landroid/view/MotionEvent;

    .line 687
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getActionMasked()I

    move-result v0

    invoke-virtual {p0, p1, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->handleTouchEvent(Landroid/view/MotionEvent;I)Z

    move-result v0

    return v0
.end method

.method handleTouchEvent(Landroid/view/MotionEvent;I)Z
    .registers 4
    .param p1, "event"    # Landroid/view/MotionEvent;
    .param p2, "eventActionOverride"    # I

    .line 691
    const/4 v0, 0x0

    invoke-virtual {p0, p1, p2, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->handleTouchEvent(Landroid/view/MotionEvent;IZ)Z

    move-result v0

    return v0
.end method

.method handleTouchEvent(Landroid/view/MotionEvent;IZ)Z
    .registers 7
    .param p1, "event"    # Landroid/view/MotionEvent;
    .param p2, "eventActionOverride"    # I
    .param p3, "doubleTap"    # Z

    .line 695
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getPointerCount()I

    move-result v0

    const/4 v1, 0x1

    if-nez v0, :cond_8

    .line 696
    return v1

    .line 699
    :cond_8
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v0

    .line 700
    .local v0, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    const/4 v2, 0x0

    if-nez v0, :cond_10

    .line 701
    return v2

    .line 704
    :cond_10
    packed-switch p2, :pswitch_data_1c

    .line 716
    :pswitch_13
    return v2

    .line 711
    :pswitch_14
    invoke-virtual {v0, p1, p2, p3}, Lorg/godotengine/godot/input/InputEventRunnable;->setTouchEvent(Landroid/view/MotionEvent;IZ)V

    .line 712
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->dispatchInputEventRunnable(Lorg/godotengine/godot/input/InputEventRunnable;)V

    .line 713
    return v1

    nop

    :pswitch_data_1c
    .packed-switch 0x0
        :pswitch_14
        :pswitch_14
        :pswitch_14
        :pswitch_14
        :pswitch_13
        :pswitch_14
        :pswitch_14
    .end packed-switch
.end method

.method hasHardwareKeyboard()Z
    .registers 3

    .line 183
    iget-boolean v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->hasHardwareKeyboardConfig:Z

    const/4 v1, 0x1

    if-eqz v0, :cond_6

    .line 184
    return v1

    .line 186
    :cond_6
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mHardwareKeyboardIds:Ljava/util/HashSet;

    invoke-virtual {v0}, Ljava/util/HashSet;->isEmpty()Z

    move-result v0

    xor-int/2addr v0, v1

    return v0
.end method

.method public initInputDevices()V
    .registers 6

    .line 341
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mInputManager:Landroid/hardware/input/InputManager;

    invoke-virtual {v0}, Landroid/hardware/input/InputManager;->getInputDeviceIds()[I

    move-result-object v0

    .line 342
    .local v0, "deviceIds":[I
    array-length v1, v0

    const/4 v2, 0x0

    :goto_8
    if-ge v2, v1, :cond_1a

    aget v3, v0, v2

    .line 343
    .local v3, "deviceId":I
    iget-object v4, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mInputManager:Landroid/hardware/input/InputManager;

    invoke-virtual {v4, v3}, Landroid/hardware/input/InputManager;->getInputDevice(I)Landroid/view/InputDevice;

    move-result-object v4

    .line 344
    .local v4, "device":Landroid/view/InputDevice;
    if-eqz v4, :cond_17

    .line 348
    invoke-virtual {p0, v3}, Lorg/godotengine/godot/input/GodotInputHandler;->onInputDeviceAdded(I)V

    .line 342
    .end local v3    # "deviceId":I
    .end local v4    # "device":Landroid/view/InputDevice;
    :cond_17
    add-int/lit8 v2, v2, 0x1

    goto :goto_8

    .line 351
    :cond_1a
    return-void
.end method

.method public onAccuracyChanged(Landroid/hardware/Sensor;I)V
    .registers 3
    .param p1, "sensor"    # Landroid/hardware/Sensor;
    .param p2, "accuracy"    # I

    .line 847
    return-void
.end method

.method public onConfigurationChanged(Landroid/content/res/Configuration;)V
    .registers 4
    .param p1, "newConfig"    # Landroid/content/res/Configuration;

    .line 854
    invoke-direct {p0}, Lorg/godotengine/godot/input/GodotInputHandler;->updateCachedRotation()V

    .line 856
    iget v0, p1, Landroid/content/res/Configuration;->keyboard:I

    const/4 v1, 0x1

    if-eq v0, v1, :cond_d

    iget v0, p1, Landroid/content/res/Configuration;->hardKeyboardHidden:I

    if-ne v0, v1, :cond_d

    goto :goto_e

    :cond_d
    const/4 v1, 0x0

    :goto_e
    move v0, v1

    .line 858
    .local v0, "newHardwareKeyboardConfig":Z
    iget-boolean v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->hasHardwareKeyboardConfig:Z

    if-eq v1, v0, :cond_1c

    .line 859
    iput-boolean v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->hasHardwareKeyboardConfig:Z

    .line 860
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotInputHandler;->hasHardwareKeyboard()Z

    move-result v1

    invoke-static {v1}, Lorg/godotengine/godot/GodotLib;->hardwareKeyboardConnected(Z)V

    .line 862
    :cond_1c
    return-void
.end method

.method public onGenericMotionEvent(Landroid/view/MotionEvent;)Z
    .registers 11
    .param p1, "event"    # Landroid/view/MotionEvent;

    .line 286
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->lastSeenToolType:Ljava/util/concurrent/atomic/AtomicInteger;

    invoke-static {p1}, Lorg/godotengine/godot/input/GodotInputHandler;->getEventToolType(Landroid/view/MotionEvent;)I

    move-result v1

    invoke-virtual {v0, v1}, Ljava/util/concurrent/atomic/AtomicInteger;->set(I)V

    .line 288
    const v0, 0x1000010

    invoke-virtual {p1, v0}, Landroid/view/MotionEvent;->isFromSource(I)Z

    move-result v0

    const/4 v1, 0x1

    if-eqz v0, :cond_a1

    invoke-virtual {p1}, Landroid/view/MotionEvent;->getActionMasked()I

    move-result v0

    const/4 v2, 0x2

    if-ne v0, v2, :cond_a1

    .line 290
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getDeviceId()I

    move-result v0

    .line 291
    .local v0, "deviceId":I
    iget-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v2, v0}, Landroid/util/SparseIntArray;->indexOfKey(I)I

    move-result v2

    if-ltz v2, :cond_9f

    .line 292
    iget-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v2, v0}, Landroid/util/SparseIntArray;->get(I)I

    move-result v2

    .line 293
    .local v2, "godotJoyId":I
    iget-object v3, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoysticksDevices:Landroid/util/SparseArray;

    invoke-virtual {v3, v0}, Landroid/util/SparseArray;->get(I)Ljava/lang/Object;

    move-result-object v3

    check-cast v3, Lorg/godotengine/godot/input/Joystick;

    .line 294
    .local v3, "joystick":Lorg/godotengine/godot/input/Joystick;
    if-nez v3, :cond_37

    .line 295
    return v1

    .line 298
    :cond_37
    const/4 v4, 0x0

    .local v4, "i":I
    :goto_38
    iget-object v5, v3, Lorg/godotengine/godot/input/Joystick;->axes:Ljava/util/List;

    invoke-interface {v5}, Ljava/util/List;->size()I

    move-result v5

    if-ge v4, v5, :cond_77

    .line 299
    iget-object v5, v3, Lorg/godotengine/godot/input/Joystick;->axes:Ljava/util/List;

    invoke-interface {v5, v4}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v5

    check-cast v5, Ljava/lang/Integer;

    invoke-virtual {v5}, Ljava/lang/Integer;->intValue()I

    move-result v5

    .line 300
    .local v5, "axis":I
    invoke-virtual {p1, v5}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v6

    .line 305
    .local v6, "value":F
    iget-object v7, v3, Lorg/godotengine/godot/input/Joystick;->axesValues:Landroid/util/SparseArray;

    invoke-virtual {v7, v5}, Landroid/util/SparseArray;->indexOfKey(I)I

    move-result v7

    if-ltz v7, :cond_68

    iget-object v7, v3, Lorg/godotengine/godot/input/Joystick;->axesValues:Landroid/util/SparseArray;

    invoke-virtual {v7, v5}, Landroid/util/SparseArray;->get(I)Ljava/lang/Object;

    move-result-object v7

    check-cast v7, Ljava/lang/Float;

    invoke-virtual {v7}, Ljava/lang/Float;->floatValue()F

    move-result v7

    cmpl-float v7, v7, v6

    if-eqz v7, :cond_74

    .line 307
    :cond_68
    iget-object v7, v3, Lorg/godotengine/godot/input/Joystick;->axesValues:Landroid/util/SparseArray;

    invoke-static {v6}, Ljava/lang/Float;->valueOf(F)Ljava/lang/Float;

    move-result-object v8

    invoke-virtual {v7, v5, v8}, Landroid/util/SparseArray;->put(ILjava/lang/Object;)V

    .line 308
    invoke-direct {p0, v2, v4, v6}, Lorg/godotengine/godot/input/GodotInputHandler;->handleJoystickAxisEvent(IIF)V

    .line 298
    .end local v5    # "axis":I
    .end local v6    # "value":F
    :cond_74
    add-int/lit8 v4, v4, 0x1

    goto :goto_38

    .line 312
    .end local v4    # "i":I
    :cond_77
    iget-boolean v4, v3, Lorg/godotengine/godot/input/Joystick;->hasAxisHat:Z

    if-eqz v4, :cond_9e

    .line 313
    const/16 v4, 0xf

    invoke-virtual {p1, v4}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v4

    invoke-static {v4}, Ljava/lang/Math;->round(F)I

    move-result v4

    .line 314
    .local v4, "hatX":I
    const/16 v5, 0x10

    invoke-virtual {p1, v5}, Landroid/view/MotionEvent;->getAxisValue(I)F

    move-result v5

    invoke-static {v5}, Ljava/lang/Math;->round(F)I

    move-result v5

    .line 315
    .local v5, "hatY":I
    iget v6, v3, Lorg/godotengine/godot/input/Joystick;->hatX:I

    if-ne v6, v4, :cond_97

    iget v6, v3, Lorg/godotengine/godot/input/Joystick;->hatY:I

    if-eq v6, v5, :cond_9e

    .line 316
    :cond_97
    iput v4, v3, Lorg/godotengine/godot/input/Joystick;->hatX:I

    .line 317
    iput v5, v3, Lorg/godotengine/godot/input/Joystick;->hatY:I

    .line 318
    invoke-direct {p0, v2, v4, v5}, Lorg/godotengine/godot/input/GodotInputHandler;->handleJoystickHatEvent(III)V

    .line 321
    .end local v4    # "hatX":I
    .end local v5    # "hatY":I
    :cond_9e
    return v1

    .line 323
    .end local v2    # "godotJoyId":I
    .end local v3    # "joystick":Lorg/godotengine/godot/input/Joystick;
    :cond_9f
    const/4 v1, 0x0

    return v1

    .line 326
    .end local v0    # "deviceId":I
    :cond_a1
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->gestureDetector:Landroid/view/GestureDetector;

    invoke-virtual {v0, p1}, Landroid/view/GestureDetector;->onGenericMotionEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    if-eqz v0, :cond_aa

    .line 328
    return v1

    .line 331
    :cond_aa
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-virtual {v0, p1}, Lorg/godotengine/godot/input/GodotGestureHandler;->onMotionEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    if-eqz v0, :cond_b3

    .line 333
    return v1

    .line 336
    :cond_b3
    invoke-virtual {p0, p1}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    return v0
.end method

.method public onInputDeviceAdded(I)V
    .registers 16
    .param p1, "deviceId"    # I

    .line 366
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v0, p1}, Landroid/util/SparseIntArray;->indexOfKey(I)I

    move-result v0

    if-ltz v0, :cond_9

    .line 367
    return-void

    .line 370
    :cond_9
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mInputManager:Landroid/hardware/input/InputManager;

    invoke-virtual {v0, p1}, Landroid/hardware/input/InputManager;->getInputDevice(I)Landroid/view/InputDevice;

    move-result-object v0

    .line 372
    .local v0, "device":Landroid/view/InputDevice;
    if-nez v0, :cond_12

    .line 373
    return-void

    .line 377
    :cond_12
    sget v1, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v2, 0x1d

    if-lt v1, v2, :cond_36

    .line 378
    const/16 v1, 0x101

    invoke-virtual {v0, v1}, Landroid/view/InputDevice;->supportsSource(I)Z

    move-result v1

    if-eqz v1, :cond_36

    .line 379
    invoke-virtual {v0}, Landroid/view/InputDevice;->isExternal()Z

    move-result v1

    if-eqz v1, :cond_36

    .line 380
    invoke-virtual {v0}, Landroid/view/InputDevice;->getKeyboardType()I

    move-result v1

    const/4 v2, 0x2

    if-ne v1, v2, :cond_36

    .line 381
    iget-object v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mHardwareKeyboardIds:Ljava/util/HashSet;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v2

    invoke-virtual {v1, v2}, Ljava/util/HashSet;->add(Ljava/lang/Object;)Z

    .line 385
    :cond_36
    const/16 v1, 0x401

    invoke-virtual {v0, v1}, Landroid/view/InputDevice;->supportsSource(I)Z

    move-result v2

    const v3, 0x1000010

    if-nez v2, :cond_48

    .line 386
    invoke-virtual {v0, v3}, Landroid/view/InputDevice;->supportsSource(I)Z

    move-result v2

    if-nez v2, :cond_48

    .line 387
    return-void

    .line 390
    :cond_48
    sget-object v2, Lorg/godotengine/godot/input/GodotInputHandler;->JOYPAD_IGNORE_LIST:[Ljava/lang/String;

    array-length v4, v2

    const/4 v5, 0x0

    :goto_4c
    if-ge v5, v4, :cond_7a

    aget-object v6, v2, v5

    .line 391
    .local v6, "name":Ljava/lang/String;
    invoke-virtual {v0}, Landroid/view/InputDevice;->getName()Ljava/lang/String;

    move-result-object v7

    invoke-virtual {v7, v6}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z

    move-result v7

    if-eqz v7, :cond_77

    .line 392
    sget-object v1, Lorg/godotengine/godot/input/GodotInputHandler;->TAG:Ljava/lang/String;

    new-instance v2, Ljava/lang/StringBuilder;

    invoke-direct {v2}, Ljava/lang/StringBuilder;-><init>()V

    const-string v3, "=== Input Device ignored: "

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v2

    invoke-virtual {v0}, Landroid/view/InputDevice;->getName()Ljava/lang/String;

    move-result-object v3

    invoke-virtual {v2, v3}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v2

    invoke-virtual {v2}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v2

    invoke-static {v1, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    .line 393
    return-void

    .line 390
    .end local v6    # "name":Ljava/lang/String;
    :cond_77
    add-int/lit8 v5, v5, 0x1

    goto :goto_4c

    .line 398
    :cond_7a
    invoke-direct {p0, p1}, Lorg/godotengine/godot/input/GodotInputHandler;->assignJoystickIdNumber(I)I

    move-result v2

    .line 400
    .local v2, "id":I
    new-instance v4, Lorg/godotengine/godot/input/Joystick;

    invoke-direct {v4}, Lorg/godotengine/godot/input/Joystick;-><init>()V

    .line 401
    .local v4, "joystick":Lorg/godotengine/godot/input/Joystick;
    iput p1, v4, Lorg/godotengine/godot/input/Joystick;->device_id:I

    .line 402
    invoke-virtual {v0}, Landroid/view/InputDevice;->getName()Ljava/lang/String;

    move-result-object v5

    iput-object v5, v4, Lorg/godotengine/godot/input/Joystick;->name:Ljava/lang/String;

    .line 405
    sget-object v5, Lorg/godotengine/godot/input/GodotInputHandler;->TAG:Ljava/lang/String;

    new-instance v6, Ljava/lang/StringBuilder;

    invoke-direct {v6}, Ljava/lang/StringBuilder;-><init>()V

    const-string v7, "=== New Input Device: "

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v6

    iget-object v7, v4, Lorg/godotengine/godot/input/Joystick;->name:Ljava/lang/String;

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v6

    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v6

    invoke-static {v5, v6}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    .line 407
    new-instance v5, Ljava/util/HashSet;

    invoke-direct {v5}, Ljava/util/HashSet;-><init>()V

    .line 408
    .local v5, "already":Ljava/util/Set;, "Ljava/util/Set<Ljava/lang/Integer;>;"
    invoke-virtual {v0}, Landroid/view/InputDevice;->getMotionRanges()Ljava/util/List;

    move-result-object v6

    invoke-interface {v6}, Ljava/util/List;->iterator()Ljava/util/Iterator;

    move-result-object v6

    :goto_b2
    invoke-interface {v6}, Ljava/util/Iterator;->hasNext()Z

    move-result v7

    const/4 v8, 0x1

    if-eqz v7, :cond_110

    invoke-interface {v6}, Ljava/util/Iterator;->next()Ljava/lang/Object;

    move-result-object v7

    check-cast v7, Landroid/view/InputDevice$MotionRange;

    .line 409
    .local v7, "range":Landroid/view/InputDevice$MotionRange;
    invoke-virtual {v7, v3}, Landroid/view/InputDevice$MotionRange;->isFromSource(I)Z

    move-result v9

    .line 410
    .local v9, "isJoystick":Z
    invoke-virtual {v7, v1}, Landroid/view/InputDevice$MotionRange;->isFromSource(I)Z

    move-result v10

    .line 411
    .local v10, "isGamepad":Z
    if-nez v9, :cond_cc

    if-nez v10, :cond_cc

    .line 412
    goto :goto_b2

    .line 414
    :cond_cc
    invoke-virtual {v7}, Landroid/view/InputDevice$MotionRange;->getAxis()I

    move-result v11

    .line 415
    .local v11, "axis":I
    const/16 v12, 0xf

    if-eq v11, v12, :cond_10d

    const/16 v12, 0x10

    if-ne v11, v12, :cond_d9

    goto :goto_10d

    .line 418
    :cond_d9
    invoke-static {v11}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v8

    invoke-interface {v5, v8}, Ljava/util/Set;->contains(Ljava/lang/Object;)Z

    move-result v8

    if-nez v8, :cond_f4

    .line 419
    invoke-static {v11}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v8

    invoke-interface {v5, v8}, Ljava/util/Set;->add(Ljava/lang/Object;)Z

    .line 420
    iget-object v8, v4, Lorg/godotengine/godot/input/Joystick;->axes:Ljava/util/List;

    invoke-static {v11}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v12

    invoke-interface {v8, v12}, Ljava/util/List;->add(Ljava/lang/Object;)Z

    goto :goto_10f

    .line 422
    :cond_f4
    sget-object v8, Lorg/godotengine/godot/input/GodotInputHandler;->TAG:Ljava/lang/String;

    new-instance v12, Ljava/lang/StringBuilder;

    invoke-direct {v12}, Ljava/lang/StringBuilder;-><init>()V

    const-string v13, " - DUPLICATE AXIS VALUE IN LIST: "

    invoke-virtual {v12, v13}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v12

    invoke-virtual {v12, v11}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v12

    invoke-virtual {v12}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v12

    invoke-static {v8, v12}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;)I

    goto :goto_10f

    .line 416
    :cond_10d
    :goto_10d
    iput-boolean v8, v4, Lorg/godotengine/godot/input/Joystick;->hasAxisHat:Z

    .line 425
    .end local v7    # "range":Landroid/view/InputDevice$MotionRange;
    .end local v9    # "isJoystick":Z
    .end local v10    # "isGamepad":Z
    .end local v11    # "axis":I
    :goto_10f
    goto :goto_b2

    .line 426
    :cond_110
    iget-object v1, v4, Lorg/godotengine/godot/input/Joystick;->axes:Ljava/util/List;

    invoke-static {v1}, Ljava/util/Collections;->sort(Ljava/util/List;)V

    .line 427
    const/4 v1, 0x0

    .local v1, "idx":I
    :goto_116
    iget-object v3, v4, Lorg/godotengine/godot/input/Joystick;->axes:Ljava/util/List;

    invoke-interface {v3}, Ljava/util/List;->size()I

    move-result v3

    if-ge v1, v3, :cond_149

    .line 429
    sget-object v3, Lorg/godotengine/godot/input/GodotInputHandler;->TAG:Ljava/lang/String;

    new-instance v6, Ljava/lang/StringBuilder;

    invoke-direct {v6}, Ljava/lang/StringBuilder;-><init>()V

    const-string v7, " - Mapping Android axis "

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v6

    iget-object v7, v4, Lorg/godotengine/godot/input/Joystick;->axes:Ljava/util/List;

    invoke-interface {v7, v1}, Ljava/util/List;->get(I)Ljava/lang/Object;

    move-result-object v7

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/Object;)Ljava/lang/StringBuilder;

    move-result-object v6

    const-string v7, " to Godot axis "

    invoke-virtual {v6, v7}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    move-result-object v6

    invoke-virtual {v6, v1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;

    move-result-object v6

    invoke-virtual {v6}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;

    move-result-object v6

    invoke-static {v3, v6}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I

    .line 427
    add-int/lit8 v1, v1, 0x1

    goto :goto_116

    .line 431
    .end local v1    # "idx":I
    :cond_149
    iget-object v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoysticksDevices:Landroid/util/SparseArray;

    invoke-virtual {v1, p1, v4}, Landroid/util/SparseArray;->put(ILjava/lang/Object;)V

    .line 433
    iget-object v1, v4, Lorg/godotengine/godot/input/Joystick;->name:Ljava/lang/String;

    invoke-direct {p0, v2, v8, v1}, Lorg/godotengine/godot/input/GodotInputHandler;->handleJoystickConnectionChangedEvent(IZLjava/lang/String;)V

    .line 434
    return-void
.end method

.method public onInputDeviceChanged(I)V
    .registers 2
    .param p1, "deviceId"    # I

    .line 452
    invoke-virtual {p0, p1}, Lorg/godotengine/godot/input/GodotInputHandler;->onInputDeviceRemoved(I)V

    .line 453
    invoke-virtual {p0, p1}, Lorg/godotengine/godot/input/GodotInputHandler;->onInputDeviceAdded(I)V

    .line 454
    return-void
.end method

.method public onInputDeviceRemoved(I)V
    .registers 5
    .param p1, "deviceId"    # I

    .line 438
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mHardwareKeyboardIds:Ljava/util/HashSet;

    invoke-static {p1}, Ljava/lang/Integer;->valueOf(I)Ljava/lang/Integer;

    move-result-object v1

    invoke-virtual {v0, v1}, Ljava/util/HashSet;->remove(Ljava/lang/Object;)Z

    .line 441
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v0, p1}, Landroid/util/SparseIntArray;->indexOfKey(I)I

    move-result v0

    if-gez v0, :cond_12

    .line 442
    return-void

    .line 444
    :cond_12
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v0, p1}, Landroid/util/SparseIntArray;->get(I)I

    move-result v0

    .line 445
    .local v0, "godotJoyId":I
    iget-object v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v1, p1}, Landroid/util/SparseIntArray;->delete(I)V

    .line 446
    iget-object v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoysticksDevices:Landroid/util/SparseArray;

    invoke-virtual {v1, p1}, Landroid/util/SparseArray;->delete(I)V

    .line 447
    const/4 v1, 0x0

    const-string v2, ""

    invoke-direct {p0, v0, v1, v2}, Lorg/godotengine/godot/input/GodotInputHandler;->handleJoystickConnectionChangedEvent(IZLjava/lang/String;)V

    .line 448
    return-void
.end method

.method public onKeyDown(ILandroid/view/KeyEvent;)Z
    .registers 15
    .param p1, "keyCode"    # I
    .param p2, "event"    # Landroid/view/KeyEvent;

    .line 232
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getSource()I

    move-result v0

    .line 234
    .local v0, "source":I
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getDeviceId()I

    move-result v1

    .line 236
    .local v1, "deviceId":I
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->isKeyEventGameDevice(I)Z

    move-result v2

    const/4 v3, 0x1

    if-eqz v2, :cond_2c

    .line 237
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getRepeatCount()I

    move-result v2

    if-lez v2, :cond_16

    .line 238
    return v3

    .line 240
    :cond_16
    iget-object v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v2, v1}, Landroid/util/SparseIntArray;->indexOfKey(I)I

    move-result v2

    if-ltz v2, :cond_4a

    .line 241
    invoke-static {p1}, Lorg/godotengine/godot/input/GodotInputHandler;->getGodotButton(I)I

    move-result v2

    .line 242
    .local v2, "button":I
    iget-object v4, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v4, v1}, Landroid/util/SparseIntArray;->get(I)I

    move-result v4

    .line 243
    .local v4, "godotJoyId":I
    invoke-direct {p0, v4, v2, v3}, Lorg/godotengine/godot/input/GodotInputHandler;->handleJoystickButtonEvent(IIZ)V

    .line 244
    .end local v2    # "button":I
    .end local v4    # "godotJoyId":I
    goto :goto_4a

    .line 246
    :cond_2c
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getKeyCode()I

    move-result v2

    .line 247
    .local v2, "physical_keycode":I
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getUnicodeChar()I

    move-result v4

    .line 248
    .local v4, "unicode":I
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getDisplayLabel()C

    move-result v11

    .line 249
    .local v11, "key_label":I
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getRepeatCount()I

    move-result v5

    if-lez v5, :cond_40

    move v10, v3

    goto :goto_42

    :cond_40
    const/4 v5, 0x0

    move v10, v5

    :goto_42
    const/4 v9, 0x1

    move-object v5, p0

    move v6, v2

    move v7, v4

    move v8, v11

    invoke-virtual/range {v5 .. v10}, Lorg/godotengine/godot/input/GodotInputHandler;->handleKeyEvent(IIIZZ)V

    .line 252
    .end local v2    # "physical_keycode":I
    .end local v4    # "unicode":I
    .end local v11    # "key_label":I
    :cond_4a
    :goto_4a
    const/16 v2, 0x18

    if-eq p1, v2, :cond_54

    const/16 v2, 0x19

    if-ne p1, v2, :cond_53

    goto :goto_54

    .line 256
    :cond_53
    return v3

    .line 253
    :cond_54
    :goto_54
    iget-boolean v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->overrideVolumeButtons:Z

    return v2
.end method

.method public onKeyUp(ILandroid/view/KeyEvent;)Z
    .registers 15
    .param p1, "keyCode"    # I
    .param p2, "event"    # Landroid/view/KeyEvent;

    .line 207
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getSource()I

    move-result v0

    .line 208
    .local v0, "source":I
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotInputHandler;->isKeyEventGameDevice(I)Z

    move-result v1

    const/4 v2, 0x1

    const/4 v3, 0x0

    if-eqz v1, :cond_26

    .line 210
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getDeviceId()I

    move-result v1

    .line 211
    .local v1, "deviceId":I
    iget-object v4, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v4, v1}, Landroid/util/SparseIntArray;->indexOfKey(I)I

    move-result v4

    if-ltz v4, :cond_25

    .line 212
    invoke-static {p1}, Lorg/godotengine/godot/input/GodotInputHandler;->getGodotButton(I)I

    move-result v4

    .line 213
    .local v4, "button":I
    iget-object v5, p0, Lorg/godotengine/godot/input/GodotInputHandler;->mJoystickIds:Landroid/util/SparseIntArray;

    invoke-virtual {v5, v1}, Landroid/util/SparseIntArray;->get(I)I

    move-result v5

    .line 214
    .local v5, "godotJoyId":I
    invoke-direct {p0, v5, v4, v3}, Lorg/godotengine/godot/input/GodotInputHandler;->handleJoystickButtonEvent(IIZ)V

    .line 216
    .end local v1    # "deviceId":I
    .end local v4    # "button":I
    .end local v5    # "godotJoyId":I
    :cond_25
    goto :goto_43

    .line 218
    :cond_26
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getKeyCode()I

    move-result v1

    .line 219
    .local v1, "physical_keycode":I
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getUnicodeChar()I

    move-result v4

    .line 220
    .local v4, "unicode":I
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getDisplayLabel()C

    move-result v5

    .line 221
    .local v5, "key_label":I
    invoke-virtual {p2}, Landroid/view/KeyEvent;->getRepeatCount()I

    move-result v6

    if-lez v6, :cond_3a

    move v11, v2

    goto :goto_3b

    :cond_3a
    move v11, v3

    :goto_3b
    const/4 v10, 0x0

    move-object v6, p0

    move v7, v1

    move v8, v4

    move v9, v5

    invoke-virtual/range {v6 .. v11}, Lorg/godotengine/godot/input/GodotInputHandler;->handleKeyEvent(IIIZZ)V

    .line 224
    .end local v1    # "physical_keycode":I
    .end local v4    # "unicode":I
    .end local v5    # "key_label":I
    :goto_43
    const/16 v1, 0x18

    if-eq p1, v1, :cond_4d

    const/16 v1, 0x19

    if-ne p1, v1, :cond_4c

    goto :goto_4d

    .line 228
    :cond_4c
    return v2

    .line 225
    :cond_4d
    :goto_4d
    iget-boolean v1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->overrideVolumeButtons:Z

    return v1
.end method

.method public onPointerCaptureChange(Z)V
    .registers 3
    .param p1, "hasCapture"    # Z

    .line 203
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-virtual {v0, p1}, Lorg/godotengine/godot/input/GodotGestureHandler;->onPointerCaptureChange(Z)V

    .line 204
    return-void
.end method

.method public onSensorChanged(Landroid/hardware/SensorEvent;)V
    .registers 11
    .param p1, "event"    # Landroid/hardware/SensorEvent;

    .line 799
    iget-object v0, p1, Landroid/hardware/SensorEvent;->values:[F

    .line 800
    .local v0, "values":[F
    if-eqz v0, :cond_53

    array-length v1, v0

    const/4 v2, 0x3

    if-eq v1, v2, :cond_9

    goto :goto_53

    .line 804
    :cond_9
    invoke-static {}, Lorg/godotengine/godot/input/InputEventRunnable;->obtain()Lorg/godotengine/godot/input/InputEventRunnable;

    move-result-object v1

    .line 805
    .local v1, "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    if-nez v1, :cond_10

    .line 806
    return-void

    .line 809
    :cond_10
    iget v2, p0, Lorg/godotengine/godot/input/GodotInputHandler;->cachedRotation:I

    const/4 v3, -0x1

    if-ne v2, v3, :cond_18

    .line 810
    invoke-direct {p0}, Lorg/godotengine/godot/input/GodotInputHandler;->updateCachedRotation()V

    .line 813
    :cond_18
    const/4 v2, 0x0

    .line 814
    .local v2, "rotatedValue0":F
    const/4 v3, 0x0

    .line 815
    .local v3, "rotatedValue1":F
    const/4 v4, 0x0

    .line 816
    .local v4, "rotatedValue2":F
    iget v5, p0, Lorg/godotengine/godot/input/GodotInputHandler;->cachedRotation:I

    const/4 v6, 0x2

    const/4 v7, 0x1

    const/4 v8, 0x0

    packed-switch v5, :pswitch_data_54

    goto :goto_44

    .line 836
    :pswitch_24
    aget v2, v0, v7

    .line 837
    aget v5, v0, v8

    neg-float v3, v5

    .line 838
    aget v4, v0, v6

    goto :goto_44

    .line 830
    :pswitch_2c
    aget v5, v0, v8

    neg-float v2, v5

    .line 831
    aget v5, v0, v7

    neg-float v3, v5

    .line 832
    aget v4, v0, v6

    .line 833
    goto :goto_44

    .line 824
    :pswitch_35
    aget v5, v0, v7

    neg-float v2, v5

    .line 825
    aget v3, v0, v8

    .line 826
    aget v4, v0, v6

    .line 827
    goto :goto_44

    .line 818
    :pswitch_3d
    aget v2, v0, v8

    .line 819
    aget v3, v0, v7

    .line 820
    aget v4, v0, v6

    .line 821
    nop

    .line 842
    :goto_44
    iget-object v5, p1, Landroid/hardware/SensorEvent;->sensor:Landroid/hardware/Sensor;

    invoke-virtual {v5}, Landroid/hardware/Sensor;->getType()I

    move-result v5

    invoke-virtual {v1, v5, v2, v3, v4}, Lorg/godotengine/godot/input/InputEventRunnable;->setSensorEvent(IFFF)V

    .line 843
    iget-object v5, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godot:Lorg/godotengine/godot/Godot;

    invoke-virtual {v5, v1}, Lorg/godotengine/godot/Godot;->runOnRenderThread(Ljava/lang/Runnable;)V

    .line 844
    return-void

    .line 801
    .end local v1    # "runnable":Lorg/godotengine/godot/input/InputEventRunnable;
    .end local v2    # "rotatedValue0":F
    .end local v3    # "rotatedValue1":F
    .end local v4    # "rotatedValue2":F
    :cond_53
    :goto_53
    return-void

    :pswitch_data_54
    .packed-switch 0x0
        :pswitch_3d
        :pswitch_35
        :pswitch_2c
        :pswitch_24
    .end packed-switch
.end method

.method public onTouchEvent(Landroid/view/MotionEvent;)Z
    .registers 5
    .param p1, "event"    # Landroid/view/MotionEvent;

    .line 260
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->lastSeenToolType:Ljava/util/concurrent/atomic/AtomicInteger;

    invoke-static {p1}, Lorg/godotengine/godot/input/GodotInputHandler;->getEventToolType(Landroid/view/MotionEvent;)I

    move-result v1

    invoke-virtual {v0, v1}, Ljava/util/concurrent/atomic/AtomicInteger;->set(I)V

    .line 262
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->scaleGestureDetector:Landroid/view/ScaleGestureDetector;

    invoke-virtual {v0, p1}, Landroid/view/ScaleGestureDetector;->onTouchEvent(Landroid/view/MotionEvent;)Z

    .line 263
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->gestureDetector:Landroid/view/GestureDetector;

    invoke-virtual {v0, p1}, Landroid/view/GestureDetector;->onTouchEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    const/4 v1, 0x1

    if-eqz v0, :cond_18

    .line 265
    return v1

    .line 268
    :cond_18
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godotGestureHandler:Lorg/godotengine/godot/input/GodotGestureHandler;

    invoke-virtual {v0, p1}, Lorg/godotengine/godot/input/GodotGestureHandler;->onMotionEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    if-eqz v0, :cond_21

    .line 270
    return v1

    .line 274
    :cond_21
    invoke-virtual {p1}, Landroid/view/MotionEvent;->getActionMasked()I

    move-result v0

    const/4 v2, 0x2

    if-ne v0, v2, :cond_29

    .line 275
    return v1

    .line 278
    :cond_29
    invoke-static {p1}, Lorg/godotengine/godot/input/GodotInputHandler;->isMouseEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    if-eqz v0, :cond_34

    .line 279
    invoke-virtual {p0, p1}, Lorg/godotengine/godot/input/GodotInputHandler;->handleMouseEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    return v0

    .line 282
    :cond_34
    invoke-virtual {p0, p1}, Lorg/godotengine/godot/input/GodotInputHandler;->handleTouchEvent(Landroid/view/MotionEvent;)Z

    move-result v0

    return v0
.end method

.method performHapticFeedback()V
    .registers 4

    .line 148
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotInputHandler;->godot:Lorg/godotengine/godot/Godot;

    invoke-virtual {v0}, Lorg/godotengine/godot/Godot;->getRenderView()Lorg/godotengine/godot/GodotRenderView;

    move-result-object v0

    .line 149
    .local v0, "view":Lorg/godotengine/godot/GodotRenderView;
    if-eqz v0, :cond_10

    .line 150
    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getView()Landroid/view/SurfaceView;

    move-result-object v1

    const/4 v2, 0x0

    invoke-virtual {v1, v2}, Landroid/view/SurfaceView;->performHapticFeedback(I)Z

    .line 152
    :cond_10
    return-void
.end method

.method public setOverrideVolumeButtons(Z)V
    .registers 2
    .param p1, "value"    # Z

    .line 179
    iput-boolean p1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->overrideVolumeButtons:Z

    .line 180
    return-void
.end method

.method public setRotaryInputAxis(I)V
    .registers 2
    .param p1, "axis"    # I

    .line 175
    iput p1, p0, Lorg/godotengine/godot/input/GodotInputHandler;->rotaryInputAxis:I

    .line 176
    return-void
.end method


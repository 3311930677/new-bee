.class public Lorg/godotengine/godot/input/GodotEditText;
.super Landroid/widget/EditText;
.source "GodotEditText.java"


# annotations
.annotation system Ldalvik/annotation/MemberClasses;
    value = {
        Lorg/godotengine/godot/input/GodotEditText$EditHandler;,
        Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;
    }
.end annotation


# static fields
.field private static final HANDLER_CLOSE_IME_KEYBOARD:I = 0x3

.field private static final HANDLER_OPEN_IME_KEYBOARD:I = 0x2


# instance fields
.field private mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

.field private mKeyboardType:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

.field private mMaxInputLength:I

.field private mOriginText:Ljava/lang/String;

.field private mRenderView:Lorg/godotengine/godot/GodotRenderView;

.field private sHandler:Lorg/godotengine/godot/input/GodotEditText$EditHandler;


# direct methods
.method static bridge synthetic -$$Nest$mhandleMessage(Lorg/godotengine/godot/input/GodotEditText;Landroid/os/Message;)V
    .registers 2

    invoke-direct {p0, p1}, Lorg/godotengine/godot/input/GodotEditText;->handleMessage(Landroid/os/Message;)V

    return-void
.end method

.method public constructor <init>(Landroid/content/Context;)V
    .registers 3
    .param p1, "context"    # Landroid/content/Context;

    .line 101
    invoke-direct {p0, p1}, Landroid/widget/EditText;-><init>(Landroid/content/Context;)V

    .line 77
    new-instance v0, Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    invoke-direct {v0, p0}, Lorg/godotengine/godot/input/GodotEditText$EditHandler;-><init>(Lorg/godotengine/godot/input/GodotEditText;)V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->sHandler:Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    .line 79
    const v0, 0x7fffffff

    iput v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mMaxInputLength:I

    .line 80
    sget-object v0, Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;->KEYBOARD_TYPE_DEFAULT:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mKeyboardType:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    .line 102
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->initView()V

    .line 103
    return-void
.end method

.method public constructor <init>(Landroid/content/Context;Landroid/util/AttributeSet;)V
    .registers 4
    .param p1, "context"    # Landroid/content/Context;
    .param p2, "attrs"    # Landroid/util/AttributeSet;

    .line 106
    invoke-direct {p0, p1, p2}, Landroid/widget/EditText;-><init>(Landroid/content/Context;Landroid/util/AttributeSet;)V

    .line 77
    new-instance v0, Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    invoke-direct {v0, p0}, Lorg/godotengine/godot/input/GodotEditText$EditHandler;-><init>(Lorg/godotengine/godot/input/GodotEditText;)V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->sHandler:Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    .line 79
    const v0, 0x7fffffff

    iput v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mMaxInputLength:I

    .line 80
    sget-object v0, Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;->KEYBOARD_TYPE_DEFAULT:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mKeyboardType:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    .line 107
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->initView()V

    .line 108
    return-void
.end method

.method public constructor <init>(Landroid/content/Context;Landroid/util/AttributeSet;I)V
    .registers 5
    .param p1, "context"    # Landroid/content/Context;
    .param p2, "attrs"    # Landroid/util/AttributeSet;
    .param p3, "defStyle"    # I

    .line 111
    invoke-direct {p0, p1, p2, p3}, Landroid/widget/EditText;-><init>(Landroid/content/Context;Landroid/util/AttributeSet;I)V

    .line 77
    new-instance v0, Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    invoke-direct {v0, p0}, Lorg/godotengine/godot/input/GodotEditText$EditHandler;-><init>(Lorg/godotengine/godot/input/GodotEditText;)V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->sHandler:Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    .line 79
    const v0, 0x7fffffff

    iput v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mMaxInputLength:I

    .line 80
    sget-object v0, Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;->KEYBOARD_TYPE_DEFAULT:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mKeyboardType:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    .line 112
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->initView()V

    .line 113
    return-void
.end method

.method private handleMessage(Landroid/os/Message;)V
    .registers 11
    .param p1, "msg"    # Landroid/os/Message;

    .line 125
    iget v0, p1, Landroid/os/Message;->what:I

    const-string v1, "input_method"

    const/4 v2, 0x0

    packed-switch v0, :pswitch_data_e0

    goto/16 :goto_df

    .line 190
    :pswitch_a
    iget-object v0, p1, Landroid/os/Message;->obj:Ljava/lang/Object;

    check-cast v0, Lorg/godotengine/godot/input/GodotEditText;

    .line 192
    .local v0, "edit":Lorg/godotengine/godot/input/GodotEditText;
    iget-object v3, p0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    invoke-virtual {v0, v3}, Lorg/godotengine/godot/input/GodotEditText;->removeTextChangedListener(Landroid/text/TextWatcher;)V

    .line 193
    iget-object v3, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v3}, Lorg/godotengine/godot/GodotRenderView;->getView()Landroid/view/SurfaceView;

    move-result-object v3

    invoke-virtual {v3}, Landroid/view/SurfaceView;->getContext()Landroid/content/Context;

    move-result-object v3

    invoke-virtual {v3, v1}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Landroid/view/inputmethod/InputMethodManager;

    .line 194
    .local v1, "imm":Landroid/view/inputmethod/InputMethodManager;
    invoke-virtual {v0}, Lorg/godotengine/godot/input/GodotEditText;->getWindowToken()Landroid/os/IBinder;

    move-result-object v3

    invoke-virtual {v1, v3, v2}, Landroid/view/inputmethod/InputMethodManager;->hideSoftInputFromWindow(Landroid/os/IBinder;I)Z

    .line 195
    iget-object v2, v0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v2}, Lorg/godotengine/godot/GodotRenderView;->getView()Landroid/view/SurfaceView;

    move-result-object v2

    invoke-virtual {v2}, Landroid/view/SurfaceView;->requestFocus()Z

    goto/16 :goto_df

    .line 127
    .end local v0    # "edit":Lorg/godotengine/godot/input/GodotEditText;
    .end local v1    # "imm":Landroid/view/inputmethod/InputMethodManager;
    :pswitch_35
    iget-object v0, p1, Landroid/os/Message;->obj:Ljava/lang/Object;

    check-cast v0, Lorg/godotengine/godot/input/GodotEditText;

    .line 128
    .restart local v0    # "edit":Lorg/godotengine/godot/input/GodotEditText;
    iget-object v3, v0, Lorg/godotengine/godot/input/GodotEditText;->mOriginText:Ljava/lang/String;

    .line 129
    .local v3, "text":Ljava/lang/String;
    invoke-virtual {v0}, Lorg/godotengine/godot/input/GodotEditText;->requestFocus()Z

    move-result v4

    if-eqz v4, :cond_de

    .line 130
    iget-object v4, v0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    invoke-virtual {v0, v4}, Lorg/godotengine/godot/input/GodotEditText;->removeTextChangedListener(Landroid/text/TextWatcher;)V

    .line 131
    invoke-direct {p0, v0}, Lorg/godotengine/godot/input/GodotEditText;->setMaxInputLength(Landroid/widget/EditText;)V

    .line 132
    const-string v4, ""

    invoke-virtual {v0, v4}, Lorg/godotengine/godot/input/GodotEditText;->setText(Ljava/lang/CharSequence;)V

    .line 133
    invoke-virtual {v0, v3}, Lorg/godotengine/godot/input/GodotEditText;->append(Ljava/lang/CharSequence;)V

    .line 134
    iget v4, p1, Landroid/os/Message;->arg2:I

    const/4 v5, -0x1

    const/4 v6, 0x1

    if-eq v4, v5, :cond_74

    .line 135
    iget v4, p1, Landroid/os/Message;->arg1:I

    invoke-virtual {v0}, Lorg/godotengine/godot/input/GodotEditText;->length()I

    move-result v5

    invoke-static {v4, v5}, Ljava/lang/Math;->min(II)I

    move-result v4

    .line 136
    .local v4, "selectionStart":I
    iget v5, p1, Landroid/os/Message;->arg2:I

    invoke-virtual {v0}, Lorg/godotengine/godot/input/GodotEditText;->length()I

    move-result v7

    invoke-static {v5, v7}, Ljava/lang/Math;->min(II)I

    move-result v5

    .line 137
    .local v5, "selectionEnd":I
    invoke-virtual {v0, v4, v5}, Lorg/godotengine/godot/input/GodotEditText;->setSelection(II)V

    .line 138
    iget-object v7, v0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    invoke-virtual {v7, v6}, Lorg/godotengine/godot/input/GodotTextInputWrapper;->setSelection(Z)V

    .line 139
    .end local v4    # "selectionStart":I
    .end local v5    # "selectionEnd":I
    goto :goto_79

    .line 140
    :cond_74
    iget-object v4, v0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    invoke-virtual {v4, v2}, Lorg/godotengine/godot/input/GodotTextInputWrapper;->setSelection(Z)V

    .line 143
    :goto_79
    const/4 v4, 0x1

    .line 144
    .local v4, "inputType":I
    const/4 v5, 0x0

    .line 145
    .local v5, "acceptCharacters":Ljava/lang/String;
    invoke-virtual {v0}, Lorg/godotengine/godot/input/GodotEditText;->getKeyboardType()Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    move-result-object v7

    invoke-virtual {v7}, Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;->ordinal()I

    move-result v7

    packed-switch v7, :pswitch_data_e8

    goto :goto_9f

    .line 169
    :pswitch_87
    const/16 v4, 0x11

    goto :goto_9f

    .line 166
    :pswitch_8a
    const/16 v4, 0x81

    .line 167
    goto :goto_9f

    .line 163
    :pswitch_8d
    const/16 v4, 0x21

    .line 164
    goto :goto_9f

    .line 160
    :pswitch_90
    const/4 v4, 0x3

    .line 161
    goto :goto_9f

    .line 156
    :pswitch_92
    const/16 v4, 0x3002

    .line 157
    const-string v5, "0123456789,.- "

    .line 158
    goto :goto_9f

    .line 153
    :pswitch_97
    const/4 v4, 0x2

    .line 154
    goto :goto_9f

    .line 150
    :pswitch_99
    const v4, 0x20001

    .line 151
    goto :goto_9f

    .line 147
    :pswitch_9d
    const/4 v4, 0x1

    .line 148
    nop

    .line 172
    :goto_9f
    invoke-virtual {v0, v4}, Lorg/godotengine/godot/input/GodotEditText;->setInputType(I)V

    .line 174
    invoke-static {v5}, Landroid/text/TextUtils;->isEmpty(Ljava/lang/CharSequence;)Z

    move-result v7

    if-nez v7, :cond_c1

    .line 175
    sget v7, Landroid/os/Build$VERSION;->SDK_INT:I

    const/16 v8, 0x1a

    if-lt v7, v8, :cond_ba

    .line 176
    invoke-static {}, Ljava/util/Locale;->getDefault()Ljava/util/Locale;

    move-result-object v7

    invoke-static {v7, v6, v6}, Landroid/text/method/DigitsKeyListener;->getInstance(Ljava/util/Locale;ZZ)Landroid/text/method/DigitsKeyListener;

    move-result-object v6

    invoke-virtual {v0, v6}, Lorg/godotengine/godot/input/GodotEditText;->setKeyListener(Landroid/text/method/KeyListener;)V

    goto :goto_c1

    .line 178
    :cond_ba
    invoke-static {v5}, Landroid/text/method/DigitsKeyListener;->getInstance(Ljava/lang/String;)Landroid/text/method/DigitsKeyListener;

    move-result-object v6

    invoke-virtual {v0, v6}, Lorg/godotengine/godot/input/GodotEditText;->setKeyListener(Landroid/text/method/KeyListener;)V

    .line 182
    :cond_c1
    :goto_c1
    iget-object v6, v0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    invoke-virtual {v6, v3}, Lorg/godotengine/godot/input/GodotTextInputWrapper;->setOriginText(Ljava/lang/String;)V

    .line 183
    iget-object v6, v0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    invoke-virtual {v0, v6}, Lorg/godotengine/godot/input/GodotEditText;->addTextChangedListener(Landroid/text/TextWatcher;)V

    .line 184
    iget-object v6, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v6}, Lorg/godotengine/godot/GodotRenderView;->getView()Landroid/view/SurfaceView;

    move-result-object v6

    invoke-virtual {v6}, Landroid/view/SurfaceView;->getContext()Landroid/content/Context;

    move-result-object v6

    invoke-virtual {v6, v1}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;

    move-result-object v1

    check-cast v1, Landroid/view/inputmethod/InputMethodManager;

    .line 185
    .restart local v1    # "imm":Landroid/view/inputmethod/InputMethodManager;
    invoke-virtual {v1, v0, v2}, Landroid/view/inputmethod/InputMethodManager;->showSoftInput(Landroid/view/View;I)Z

    .line 187
    .end local v0    # "edit":Lorg/godotengine/godot/input/GodotEditText;
    .end local v1    # "imm":Landroid/view/inputmethod/InputMethodManager;
    .end local v3    # "text":Ljava/lang/String;
    .end local v4    # "inputType":I
    .end local v5    # "acceptCharacters":Ljava/lang/String;
    :cond_de
    nop

    .line 198
    :goto_df
    return-void

    :pswitch_data_e0
    .packed-switch 0x2
        :pswitch_35
        :pswitch_a
    .end packed-switch

    :pswitch_data_e8
    .packed-switch 0x0
        :pswitch_9d
        :pswitch_99
        :pswitch_97
        :pswitch_92
        :pswitch_90
        :pswitch_8d
        :pswitch_8a
        :pswitch_87
    .end packed-switch
.end method

.method private needHandlingInGodot(ILandroid/view/KeyEvent;)Z
    .registers 8
    .param p1, "keyCode"    # I
    .param p2, "keyEvent"    # Landroid/view/KeyEvent;

    .line 286
    const/16 v0, 0x13

    const/4 v1, 0x0

    const/4 v2, 0x1

    if-eq p1, v0, :cond_15

    const/16 v0, 0x14

    if-eq p1, v0, :cond_15

    const/16 v0, 0x15

    if-eq p1, v0, :cond_15

    const/16 v0, 0x16

    if-ne p1, v0, :cond_13

    goto :goto_15

    :cond_13
    move v0, v1

    goto :goto_16

    :cond_15
    :goto_15
    move v0, v2

    .line 288
    .local v0, "isArrowKey":Z
    :goto_16
    invoke-virtual {p2}, Landroid/view/KeyEvent;->isAltPressed()Z

    move-result v3

    if-nez v3, :cond_37

    invoke-virtual {p2}, Landroid/view/KeyEvent;->isCtrlPressed()Z

    move-result v3

    if-nez v3, :cond_37

    invoke-virtual {p2}, Landroid/view/KeyEvent;->isSymPressed()Z

    move-result v3

    if-nez v3, :cond_37

    .line 289
    invoke-virtual {p2}, Landroid/view/KeyEvent;->isFunctionPressed()Z

    move-result v3

    if-nez v3, :cond_37

    invoke-virtual {p2}, Landroid/view/KeyEvent;->isMetaPressed()Z

    move-result v3

    if-eqz v3, :cond_35

    goto :goto_37

    :cond_35
    move v3, v1

    goto :goto_38

    :cond_37
    :goto_37
    move v3, v2

    .line 290
    .local v3, "isModifiedKey":Z
    :goto_38
    if-nez v0, :cond_46

    const/16 v4, 0x3d

    if-eq p1, v4, :cond_46

    invoke-static {p1}, Landroid/view/KeyEvent;->isModifierKey(I)Z

    move-result v4

    if-nez v4, :cond_46

    if-eqz v3, :cond_47

    :cond_46
    move v1, v2

    :cond_47
    return v1
.end method

.method private setMaxInputLength(Landroid/widget/EditText;)V
    .registers 5
    .param p1, "p_edit_text"    # Landroid/widget/EditText;

    .line 201
    const/4 v0, 0x1

    new-array v0, v0, [Landroid/text/InputFilter;

    .line 202
    .local v0, "filters":[Landroid/text/InputFilter;
    new-instance v1, Landroid/text/InputFilter$LengthFilter;

    iget v2, p0, Lorg/godotengine/godot/input/GodotEditText;->mMaxInputLength:I

    invoke-direct {v1, v2}, Landroid/text/InputFilter$LengthFilter;-><init>(I)V

    const/4 v2, 0x0

    aput-object v1, v0, v2

    .line 203
    invoke-virtual {p1, v0}, Landroid/widget/EditText;->setFilters([Landroid/text/InputFilter;)V

    .line 204
    return-void
.end method


# virtual methods
.method public getKeyboardType()Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;
    .registers 2

    .line 121
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mKeyboardType:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    return-object v0
.end method

.method public hasHardwareKeyboard()Z
    .registers 2

    .line 295
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v0

    invoke-virtual {v0}, Lorg/godotengine/godot/input/GodotInputHandler;->hasHardwareKeyboard()Z

    move-result v0

    return v0
.end method

.method public hideKeyboard()V
    .registers 3

    .line 333
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->hasHardwareKeyboard()Z

    move-result v0

    if-eqz v0, :cond_7

    .line 334
    return-void

    .line 337
    :cond_7
    new-instance v0, Landroid/os/Message;

    invoke-direct {v0}, Landroid/os/Message;-><init>()V

    .line 338
    .local v0, "msg":Landroid/os/Message;
    const/4 v1, 0x3

    iput v1, v0, Landroid/os/Message;->what:I

    .line 339
    iput-object p0, v0, Landroid/os/Message;->obj:Ljava/lang/Object;

    .line 340
    iget-object v1, p0, Lorg/godotengine/godot/input/GodotEditText;->sHandler:Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    invoke-virtual {v1, v0}, Lorg/godotengine/godot/input/GodotEditText$EditHandler;->sendMessage(Landroid/os/Message;)Z

    .line 341
    return-void
.end method

.method protected initView()V
    .registers 2

    .line 116
    const/4 v0, 0x0

    invoke-virtual {p0, v0, v0, v0, v0}, Lorg/godotengine/godot/input/GodotEditText;->setPadding(IIII)V

    .line 117
    const v0, 0x10000006

    invoke-virtual {p0, v0}, Lorg/godotengine/godot/input/GodotEditText;->setImeOptions(I)V

    .line 118
    return-void
.end method

.method public onKeyDown(ILandroid/view/KeyEvent;)Z
    .registers 11
    .param p1, "keyCode"    # I
    .param p2, "keyEvent"    # Landroid/view/KeyEvent;

    .line 223
    const/4 v0, 0x4

    if-ne p1, v0, :cond_1a

    .line 225
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->clearFocus()V

    .line 228
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getView()Landroid/view/SurfaceView;

    move-result-object v0

    invoke-virtual {v0}, Landroid/view/SurfaceView;->requestFocus()Z

    .line 232
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v0

    invoke-virtual {v0, p1, p2}, Lorg/godotengine/godot/input/GodotInputHandler;->onKeyDown(ILandroid/view/KeyEvent;)Z

    move-result v0

    return v0

    .line 238
    :cond_1a
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->hasHardwareKeyboard()Z

    move-result v0

    if-eqz v0, :cond_2b

    .line 239
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v0

    invoke-virtual {v0, p1, p2}, Lorg/godotengine/godot/input/GodotInputHandler;->onKeyDown(ILandroid/view/KeyEvent;)Z

    move-result v0

    return v0

    .line 245
    :cond_2b
    const/16 v0, 0x43

    const/4 v1, 0x1

    if-ne p1, v0, :cond_46

    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->length()I

    move-result v0

    if-nez v0, :cond_46

    .line 246
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v2

    const/4 v6, 0x1

    const/4 v7, 0x0

    const/16 v3, 0x43

    const/4 v4, 0x0

    const/4 v5, 0x0

    invoke-virtual/range {v2 .. v7}, Lorg/godotengine/godot/input/GodotInputHandler;->handleKeyEvent(IIIZZ)V

    .line 247
    return v1

    .line 251
    :cond_46
    invoke-direct {p0, p1, p2}, Lorg/godotengine/godot/input/GodotEditText;->needHandlingInGodot(ILandroid/view/KeyEvent;)Z

    move-result v0

    if-eqz v0, :cond_59

    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v0

    invoke-virtual {v0, p1, p2}, Lorg/godotengine/godot/input/GodotInputHandler;->onKeyDown(ILandroid/view/KeyEvent;)Z

    move-result v0

    if-eqz v0, :cond_59

    .line 252
    return v1

    .line 254
    :cond_59
    invoke-super {p0, p1, p2}, Landroid/widget/EditText;->onKeyDown(ILandroid/view/KeyEvent;)Z

    move-result v0

    return v0
.end method

.method public onKeyUp(ILandroid/view/KeyEvent;)Z
    .registers 11
    .param p1, "keyCode"    # I
    .param p2, "keyEvent"    # Landroid/view/KeyEvent;

    .line 263
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->hasHardwareKeyboard()Z

    move-result v0

    if-eqz v0, :cond_11

    .line 264
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v0

    invoke-virtual {v0, p1, p2}, Lorg/godotengine/godot/input/GodotInputHandler;->onKeyUp(ILandroid/view/KeyEvent;)Z

    move-result v0

    return v0

    .line 268
    :cond_11
    const/4 v0, 0x4

    if-ne p1, v0, :cond_25

    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->hasFocus()Z

    move-result v0

    if-nez v0, :cond_25

    .line 269
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v0

    invoke-virtual {v0, p1, p2}, Lorg/godotengine/godot/input/GodotInputHandler;->onKeyUp(ILandroid/view/KeyEvent;)Z

    move-result v0

    return v0

    .line 273
    :cond_25
    const/16 v0, 0x43

    const/4 v1, 0x1

    if-ne p1, v0, :cond_40

    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->length()I

    move-result v0

    if-nez v0, :cond_40

    .line 274
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v2

    const/4 v6, 0x0

    const/4 v7, 0x0

    const/16 v3, 0x43

    const/4 v4, 0x0

    const/4 v5, 0x0

    invoke-virtual/range {v2 .. v7}, Lorg/godotengine/godot/input/GodotInputHandler;->handleKeyEvent(IIIZZ)V

    .line 275
    return v1

    .line 278
    :cond_40
    invoke-direct {p0, p1, p2}, Lorg/godotengine/godot/input/GodotEditText;->needHandlingInGodot(ILandroid/view/KeyEvent;)Z

    move-result v0

    if-eqz v0, :cond_53

    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-interface {v0}, Lorg/godotengine/godot/GodotRenderView;->getInputHandler()Lorg/godotengine/godot/input/GodotInputHandler;

    move-result-object v0

    invoke-virtual {v0, p1, p2}, Lorg/godotengine/godot/input/GodotInputHandler;->onKeyUp(ILandroid/view/KeyEvent;)Z

    move-result v0

    if-eqz v0, :cond_53

    .line 279
    return v1

    .line 281
    :cond_53
    invoke-super {p0, p1, p2}, Landroid/widget/EditText;->onKeyUp(ILandroid/view/KeyEvent;)Z

    move-result v0

    return v0
.end method

.method public setView(Lorg/godotengine/godot/GodotRenderView;)V
    .registers 4
    .param p1, "view"    # Lorg/godotengine/godot/GodotRenderView;

    .line 210
    iput-object p1, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    .line 211
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    if-nez v0, :cond_f

    .line 212
    new-instance v0, Lorg/godotengine/godot/input/GodotTextInputWrapper;

    iget-object v1, p0, Lorg/godotengine/godot/input/GodotEditText;->mRenderView:Lorg/godotengine/godot/GodotRenderView;

    invoke-direct {v0, v1, p0}, Lorg/godotengine/godot/input/GodotTextInputWrapper;-><init>(Lorg/godotengine/godot/GodotRenderView;Lorg/godotengine/godot/input/GodotEditText;)V

    iput-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    .line 213
    :cond_f
    iget-object v0, p0, Lorg/godotengine/godot/input/GodotEditText;->mInputWrapper:Lorg/godotengine/godot/input/GodotTextInputWrapper;

    invoke-virtual {p0, v0}, Lorg/godotengine/godot/input/GodotEditText;->setOnEditorActionListener(Landroid/widget/TextView$OnEditorActionListener;)V

    .line 214
    invoke-interface {p1}, Lorg/godotengine/godot/GodotRenderView;->getView()Landroid/view/SurfaceView;

    move-result-object v0

    invoke-virtual {v0}, Landroid/view/SurfaceView;->requestFocus()Z

    .line 215
    return-void
.end method

.method public showKeyboard(Ljava/lang/String;Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;III)V
    .registers 11
    .param p1, "p_existing_text"    # Ljava/lang/String;
    .param p2, "p_type"    # Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;
    .param p3, "p_max_input_length"    # I
    .param p4, "p_cursor_start"    # I
    .param p5, "p_cursor_end"    # I

    .line 302
    invoke-virtual {p0}, Lorg/godotengine/godot/input/GodotEditText;->hasHardwareKeyboard()Z

    move-result v0

    if-eqz v0, :cond_7

    .line 303
    return-void

    .line 306
    :cond_7
    move v0, p4

    .line 307
    .local v0, "cursorStart":I
    move v1, p5

    .line 308
    .local v1, "cursorEnd":I
    if-gtz p3, :cond_f

    const v2, 0x7fffffff

    goto :goto_10

    :cond_f
    move v2, p3

    .line 309
    .local v2, "maxInputLength":I
    :goto_10
    const/4 v3, -0x1

    if-ne v0, v3, :cond_18

    .line 310
    iput-object p1, p0, Lorg/godotengine/godot/input/GodotEditText;->mOriginText:Ljava/lang/String;

    .line 311
    iput v2, p0, Lorg/godotengine/godot/input/GodotEditText;->mMaxInputLength:I

    goto :goto_4a

    .line 312
    :cond_18
    const/4 v4, 0x0

    if-ne v1, v3, :cond_33

    .line 313
    invoke-virtual {p1}, Ljava/lang/String;->length()I

    move-result v3

    invoke-static {v3, v0}, Ljava/lang/Math;->min(II)I

    move-result v0

    .line 314
    invoke-virtual {p1, v4, v0}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object v3

    iput-object v3, p0, Lorg/godotengine/godot/input/GodotEditText;->mOriginText:Ljava/lang/String;

    .line 315
    invoke-virtual {p1}, Ljava/lang/String;->length()I

    move-result v3

    sub-int/2addr v3, v0

    sub-int v3, v2, v3

    iput v3, p0, Lorg/godotengine/godot/input/GodotEditText;->mMaxInputLength:I

    goto :goto_4a

    .line 317
    :cond_33
    invoke-virtual {p1}, Ljava/lang/String;->length()I

    move-result v3

    invoke-static {v3, v1}, Ljava/lang/Math;->min(II)I

    move-result v1

    .line 318
    invoke-virtual {p1, v4, v1}, Ljava/lang/String;->substring(II)Ljava/lang/String;

    move-result-object v3

    iput-object v3, p0, Lorg/godotengine/godot/input/GodotEditText;->mOriginText:Ljava/lang/String;

    .line 319
    invoke-virtual {p1}, Ljava/lang/String;->length()I

    move-result v3

    sub-int/2addr v3, v1

    sub-int v3, v2, v3

    iput v3, p0, Lorg/godotengine/godot/input/GodotEditText;->mMaxInputLength:I

    .line 322
    :goto_4a
    iput-object p2, p0, Lorg/godotengine/godot/input/GodotEditText;->mKeyboardType:Lorg/godotengine/godot/input/GodotEditText$VirtualKeyboardType;

    .line 324
    new-instance v3, Landroid/os/Message;

    invoke-direct {v3}, Landroid/os/Message;-><init>()V

    .line 325
    .local v3, "msg":Landroid/os/Message;
    const/4 v4, 0x2

    iput v4, v3, Landroid/os/Message;->what:I

    .line 326
    iput-object p0, v3, Landroid/os/Message;->obj:Ljava/lang/Object;

    .line 327
    iput v0, v3, Landroid/os/Message;->arg1:I

    .line 328
    iput v1, v3, Landroid/os/Message;->arg2:I

    .line 329
    iget-object v4, p0, Lorg/godotengine/godot/input/GodotEditText;->sHandler:Lorg/godotengine/godot/input/GodotEditText$EditHandler;

    invoke-virtual {v4, v3}, Lorg/godotengine/godot/input/GodotEditText$EditHandler;->sendMessage(Landroid/os/Message;)Z

    .line 330
    return-void
.end method


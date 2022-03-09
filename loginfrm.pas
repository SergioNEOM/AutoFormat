unit LoginFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons;

const
  FORM_MODE_ADD      = -999;
  FORM_MODE_LOGIN    = 0;
  // else - FORM_MODE_EDIT     >0;


type

  { TLoginForm }

  TLoginForm = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    LoginField: TLabeledEdit;
    Panel1: TPanel;
    LoginPanel: TPanel;
    PassField2: TLabeledEdit;
    RadioGroup1: TRadioGroup;
    RepeatPanel: TPanel;
    UserNamePanel: TPanel;
    PassField: TLabeledEdit;
    UserNameField: TLabeledEdit;
    procedure BitBtn2Click(Sender: TObject);
    procedure FormCreate(Sender: TObject);
  private
    FMode : integer;
  public
    CurrentUserId : integer;
    constructor Create(TheOwner: TComponent; Mode: integer = 0);
  end;

var
  LoginForm: TLoginForm;

implementation

{$R *.lfm}
uses  StrUtils, LCLType, DM, CommonUnit;

{ TLoginForm }

constructor TLoginForm.Create(TheOwner: TComponent; Mode: integer = 0);
begin
  inherited Create(TheOwner);
  FMode := Mode;
  if Mode > 0 then CurrentUserId:=Mode;
end;

procedure TLoginForm.BitBtn2Click(Sender: TObject);
var
  admin : string;
begin
  if (FMode <> FORM_MODE_LOGIN) and (PassField.Text <> PassField2.Text) then
  begin
    Application.MessageBox('Поля паролей должны совпадать!','Ошибка',MB_ICONERROR+MB_OK);
    Exit;
  end;
  if IsEmptyStr(LoginField.Text, [' ']) or IsEmptyStr(PassField.Text, [' ']) then
  begin
    Application.MessageBox('Поля Login/Пароль не должны быть пустыми','Ошибка',MB_ICONERROR+MB_OK);
    Exit;
  end;

  case FMode of
    FORM_MODE_LOGIN:
      begin
        if DM1.CheckUser(Trim(LoginField.Text), Trim(PassField.Text))>0  then ModalResult:=mrOk
        else
        begin
          Application.MessageBox('login error','',MB_ICONERROR+MB_OK);
          Exit;
        end;
      end;
    FORM_MODE_ADD:
      begin
        admin := '';
        case RadioGroup1.ItemIndex of
          1: admin := 'C';
          2: admin := '*';
        end;
        CurrentUserId := DM1.AddUser(LoginField.Text,PassField.Text,UserNameField.Text,admin);
        if CurrentUserId<=0 then
        begin
          showmessage('Ошибка добавления пользователя'); //TODO: debug log
          Exit;
        end;
        ModalResult:=mrOk;
      end;
    else
      begin
        // Edit mode

      end;
  end;
end;

procedure TLoginForm.FormCreate(Sender: TObject);
begin
  case FMode of
    FORM_MODE_ADD:
      begin
        //TODO: ??? do nothing ???
      end;
    FORM_MODE_LOGIN:
      begin
        UserNamePanel.Visible:=False;
        UserNamePanel.Enabled:=False;
        RepeatPanel.Visible:=False;
        RepeatPanel.Enabled:=False;
        ClientHeight:=LoginPanel.Height;
      end;
    else //FORM_MODE_EDIT
      begin
        //TODO: if DM1.Users.Active then UserNameField.Text:=DM1.GetUserById;
        PassField.EditLabel.Caption:='НОВЫЙ пароль:';
      end;
  end;
end;

end.


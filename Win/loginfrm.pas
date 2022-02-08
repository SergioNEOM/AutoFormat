unit LoginFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons;

type

  { TLoginForm }

  TLoginForm = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    PassField: TLabeledEdit;
    LoginField: TLabeledEdit;
    procedure BitBtn2Click(Sender: TObject);
  private

  public

  end;

var
  LoginForm: TLoginForm;

implementation

{$R *.lfm}
uses  StrUtils, LCLType, md5, DM;

{ TLoginForm }

procedure TLoginForm.BitBtn2Click(Sender: TObject);
var
  mdStr : String;
begin
  if IsEmptyStr(LoginField.Text, [' ']) or IsEmptyStr(PassField.Text, [' ']) then
  begin
    Application.MessageBox('Empty field','',MB_ICONERROR+MB_OK);
    Exit;
  end;
  mdStr := MD5Print(MD5String('SVS'+Trim(PassField.Text)+'SVS'));
  if DM1.CheckUser(Trim(LoginField.Text), mdStr)<=0 then
  begin
    Application.MessageBox('login error','',MB_ICONERROR+MB_OK);
    Exit
  end;
end;

end.


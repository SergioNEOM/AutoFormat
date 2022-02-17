unit InputMemoFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons;

type

  { TInputMemoForm }

  TInputMemoForm = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    Memo1: TMemo;
    Panel1: TPanel;
  private

  public

  end;

var
  InputMemoForm: TInputMemoForm;

implementation

{$R *.lfm}

end.


unit GetFileFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, EditBtn,
  Buttons;

type

  { TGetFileForm1 }

  TGetFileForm1 = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    FileNameEdit1: TFileNameEdit;
    Panel1: TPanel;
  private

  public

  end;

var
  GetFileForm1: TGetFileForm1;

implementation

{$R *.lfm}

end.


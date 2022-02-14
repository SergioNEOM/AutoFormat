unit ListFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons, db,
  DBGrids;

resourcestring
  FormHeader = 'Справочник: ';

type

  { TListForm1 }

  TListForm1 = class(TForm)
    CancelButton: TBitBtn;
    DBGrid1: TDBGrid;
    OkButton: TBitBtn;
    Panel1: TPanel;
  private

  public
    Current_id : integer;
    constructor Create(TheOwner: TComponent; DS: TDataSource; ListName:string = ''; id: integer = -1);
  end;

var
  ListForm1: TListForm1;

implementation

{$R *.lfm}

constructor TListForm1.Create(TheOwner: TComponent; DS: TDataSource; ListName:string = ''; id: integer = -1);
begin
  inherited Create(TheOwner);
  self.Caption:=FormHeader + Trim(ListName);
  DBGrid1.DataSource := DS;
  if Assigned(DS) and (id > 0) and DS.DataSet.Locate('id',id,[]) then
    Current_id := id
  else
    // no records in DS
    OkButton.Enabled:=False;
    Current_id:=-1;
end;

end.

unit ListFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons, db,
  DBGrids, StdCtrls;

resourcestring
  FormHeader = 'Справочник: ';

type

  { TUserListForm }

  TUserListForm = class(TForm)
    DBGrid1: TDBGrid;
    OkButton: TBitBtn;
    Panel1: TPanel;
  private

  public
    Current_id : integer;
    //constructor Create(TheOwner: TComponent; DS: TDataSource; ListName:string = ''; id: integer = -1);
  end;

var
  UserListForm: TUserListForm;

implementation

{$R *.lfm}

{constructor TUserListForm.Create(TheOwner: TComponent; DS: TDataSource; ListName:string = ''; id: integer = -1);
begin
  inherited Create(TheOwner);
  self.Caption:=FormHeader + Trim(ListName);
  if not Assigned(DS) or (DS.DataSet.RecordCount<1)  then
  begin
    // no records in DS
    OkButton.Enabled:=False;
    Current_id:=-1;
    Exit;
  end;
  DBGrid1.DataSource := DS;
  if DS.DataSet.Locate('id',id,[]) then Current_id := id
  else
  begin
    DS.DataSet.First;
    Current_id:=DS.DataSet.FieldByName('id').AsInteger;
  end;
end;
}
end.


unit ListFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, ExtCtrls, Buttons, db,
  DBGrids, StdCtrls, Grids;

resourcestring
  FormHeader = 'Список пользователей';

type

  { TUserListForm }

  TUserListForm = class(TForm)
    AddBitBtn: TBitBtn;
    EditBitBtn: TBitBtn;
    DelBitBtn: TBitBtn;
    DBGrid1: TDBGrid;
    OkButton: TBitBtn;
    Panel1: TPanel;
    procedure AddBitBtnClick(Sender: TObject);
    procedure DBGrid1DrawColumnCell(Sender: TObject; const Rect: TRect;
      DataCol: Integer; Column: TColumn; State: TGridDrawState);
    procedure DelBitBtnClick(Sender: TObject);
    procedure EditBitBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
  private

  public
    Current_id : integer;
    //constructor Create(TheOwner: TComponent; DS: TDataSource; ListName:string = ''; id: integer = -1);
  end;

var
  UserListForm: TUserListForm;

implementation

{$R *.lfm}

uses LoginFrm, DM;

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

{ TUserListForm }

procedure TUserListForm.FormCreate(Sender: TObject);
begin
  try
    if DM1.Users.Active then DM1.Users.Refresh
    else DM1.Users.Open;
  except
  end;
end;

procedure TUserListForm.FormShow(Sender: TObject);
begin
    DBGrid1.SetFocus;
end;


procedure TUserListForm.AddBitBtnClick(Sender: TObject);
begin
  with TLoginForm.Create(self,FORM_MODE_ADD) do
  try
    if ShowModal=mrOK then
    begin
      DBGrid1.DataSource.DataSet.Refresh;
      DBGrid1.DataSource.DataSet.Locate('id',CurrentUserId,[]);
    end;
  finally
    Free;
  end;
end;

procedure TUserListForm.DBGrid1DrawColumnCell(Sender: TObject;
  const Rect: TRect; DataCol: Integer; Column: TColumn; State: TGridDrawState);
var
  s : string;
begin
  s := '';
  if (Column.FieldName='superuser') then
      with TDBGrid(sender).Canvas do
      begin
        if Column.Field.AsString='*' then
        begin
          s:='Менеджер пользователей';
          if not (gdSelected in State) then
          begin
            Brush.Color:=clWhite;
            Font.Color:=clRed;
          end
          else
            Font.Style:=Font.Style+[fsBold];
        end;
        if Column.Field.AsString='C' then
        begin
          s:='Создатель шаблонов';
          if not (gdSelected in State) then
          begin
            Brush.Color:=$CCFFFF;
            Font.Color:=clBlue;
          end
          else
            Font.Style:=Font.Style+[fsItalic];
        end;
        FillRect(Rect);
        if (Column.Alignment=taRightJustify) then
          TextOut(Rect.Right-2-TextWidth(s),Rect.Top+2,s)
        else
          TextOut(Rect.Left+2,Rect.Top+2,s);
      end;
end;

procedure TUserListForm.DelBitBtnClick(Sender: TObject);
begin
  if not DBGrid1.DataSource.DataSet.Active then Exit;
  if DBGrid1.DataSource.DataSet.IsEmpty then Exit;
  if MessageDlg('Запрос удаления','Будет удален пользователь:'+#13#10+
     DBGrid1.DataSource.DataSet.FieldByName('username').AsString+
     #13#10+'Вы уверены?',mtConfirmation,mbYesNo,'')<>mrYes then Exit;
  //TODO: проверить, что нет связных записей в других таблицах. Если есть, то доп.запрос на удаление
  if not DM1.DelUser(DBGrid1.DataSource.DataSet.FieldByName('id').AsInteger) then
  begin
    showmessage('ошибка удаления пользователя');
    Exit;
  end;
  DBGrid1.DataSource.DataSet.Refresh;
end;

procedure TUserListForm.EditBitBtnClick(Sender: TObject);
var
  role : char;
begin
  if not DBGrid1.DataSource.DataSet.Active then Exit;
  if DBGrid1.DataSource.DataSet.IsEmpty then Exit;
  with TLoginForm.Create(self, DBGrid1.DataSource.DataSet.FieldByName('id').AsInteger) do
  try
    //TODO: не получается отделить данные от формы?
    UserNameField.Text:= DBGrid1.DataSource.DataSet.FieldByName('username').AsString;
    LoginField.Text:= DBGrid1.DataSource.DataSet.FieldByName('login').AsString;
    RadioGroup1.ItemIndex:=0;
    role := Trim(DBGrid1.DataSource.DataSet.FieldByName('superuser').AsString)[1];
    case role of
      'C' : RadioGroup1.ItemIndex:=1;
      '*' : RadioGroup1.ItemIndex:=2;
    end;
    if ShowModal=mrOK then DBGrid1.DataSource.DataSet.Refresh;
  finally
    Free;
  end;
end;


end.


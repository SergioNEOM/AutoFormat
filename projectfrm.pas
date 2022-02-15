unit ProjectFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, DBCtrls, EditBtn;

type

  { TProjectForm }

  TProjectForm = class(TForm)
    Button3: TButton;
    CentralPanel: TPanel;
    ComboBox1: TComboBox;
    ListBox1: TListBox;
    OkButton: TBitBtn;
    CancelButton: TBitBtn;
    BottomPanel: TPanel;
    OpenDialog1: TOpenDialog;
    PrjInfoLabel: TLabel;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    StaticText1: TStaticText;
    TopPanel: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure SpeedButton1Click(Sender: TObject);
  private

  public
    //constructor Create(TheOwner: TComponent; Proj_id : integer = -1);
    function AddProject : integer;
  end;

var
  ProjectForm: TProjectForm;

implementation

{$R *.lfm}

uses LCLType, MainForm, DM;

{ TProjectForm }

{constructor TProjectForm.Create(TheOwner: TComponent; Proj_id : integer = -1);
begin
  inherited Create(TheOwner);
  if Proj_id<=0 then         // no project ??? - error
  begin
    Application.MessageBox('Error adding project','ERROR', MB_ICONERROR+MB_OK);
    Close;
  end;
end;
}

procedure TProjectForm.FormCreate(Sender: TObject);
begin
  if MainForm1.CurrentProject.id >0 then
  begin
    PrjInfoLabel.Caption:=MainForm1.CurrentProject.prjinfo;
  end
  else
  begin
    // no current project ?
    // make sure:  will be no mistakes
    PrjInfoLabel.Caption:='Ошибка!!!'#13#10' Нет текущего проекта!';
    TopPanel.Enabled:=False;
    CentralPanel.Enabled:=False;
    OkButton.Enabled:=False;
  end;
end;

procedure TProjectForm.SpeedButton1Click(Sender: TObject);
var
  t : integer;
begin
  if not OpenDialog1.Execute then Exit;
  t := DM1.InsertTemplate(
        MainForm1.CurrentProject.id,
        InputBox('Ввод данных','Введите описание шаблона',''),
        OpenDialog1.FileName);
  showmessage(inttostr(t));
end;

function TProjectForm.AddProject: integer;
begin
  // insert into projects new rec
  // MainForm1.CurrentUser.project := new.id;
  Result := -1;

end;

end.


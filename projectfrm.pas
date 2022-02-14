unit ProjectFrm;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, DBCtrls, EditBtn;

type

  { TProjectForm }

  TProjectForm = class(TForm)
    OkButton: TBitBtn;
    CancelButton: TBitBtn;
    Button1: TButton;
    Button2: TButton;
    BottomPanel: TPanel;
    CentralPanel: TPanel;
    ListBox1: TListBox;
    PrjInfoLabel: TLabel;
    SpeedButton1: TSpeedButton;
    SpeedButton2: TSpeedButton;
    SpeedButton3: TSpeedButton;
    SpeedButton4: TSpeedButton;
    SpeedButton5: TSpeedButton;
    StaticText1: TStaticText;
    TopPanel: TPanel;
    procedure FormCreate(Sender: TObject);
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
    TopPanel.Enabled:=False;
    CentralPanel.Enabled:=False;
    OkButton.Enabled:=False;
  end;
end;

function TProjectForm.AddProject: integer;
begin
  // insert into projects new rec
  // MainForm1.CurrentUser.project := new.id;
  Result := -1;

end;

end.


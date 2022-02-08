program TestMsOffice;

{$IFDEF FPC}
 {$MODE Delphi}
{$ELSE}
 {$APPTYPE CONSOLE}
{$ENDIF} 

uses
  SysUtils, Variants, ComObj;

const
  ServerName = 'Word.Application';
var
  Server     : Variant;
  w:widestring;
begin
  if Assigned(InitProc) then
    TProcedure(InitProc);

  try
    Server := CreateOleObject(ServerName);
  except
    WriteLn('Unable to start Word.');
    Exit;
  end;

   {Open existing document}  //Substitute your path and doc
  w:= UTF8Decode('c:\my\path\mydoc.doc');
  Server.Documents.Open(w); //OLE uses BSTR (http://msdn.microsoft.com/en-us/library/windows/desktop/ms221069(v=vs.85).aspx). Only widestring is compatible with BSTR in FPC, so conversion is needed for nonlatin chars.
  Server.Visible := True;  {Make Word visible}

end.
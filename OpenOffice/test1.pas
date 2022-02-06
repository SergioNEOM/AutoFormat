program TestOO;

{$IFDEF FPC}
 {$MODE Delphi}
{$ELSE}
 {$APPTYPE CONSOLE}
{$ENDIF} 

uses
  SysUtils, Variants, ComObj;

const
  ServerName = 'com.sun.star.ServiceManager';
var          
  Server     : Variant;
  Desktop    : Variant;
  LoadParams : Variant;
  Document   : Variant;
  TextCursor : Variant;
begin
  if Assigned(InitProc) then
    TProcedure(InitProc);

  try
    Server := CreateOleObject(ServerName);
  except
    WriteLn('Unable to start OO.');
    Exit;
  end;

  Desktop := Server.CreateInstance('com.sun.star.frame.Desktop');

  LoadParams := VarArrayCreate([0, -1], varVariant);

   {Create new document}
  Document := Desktop.LoadComponentFromURL('private:factory/swriter', '_blank', 0, LoadParams);

   {or Open existing} //you must use forward slashes, not backward!
  //Document := Desktop.LoadComponentFromURL('file:///C:/my/path/mydoc.doc', '_blank', 0, LoadParams); 

  TextCursor := Document.Text.CreateTextCursor;

   {Insert existing document}  //Substitute your path and doc
  TextCursor.InsertDocumentFromURL('file:///C:/my/path/mydoc.doc', LoadParams);
end.

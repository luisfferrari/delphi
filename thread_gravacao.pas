unit thread_gravacao;

interface

uses
   Windows, Messages, SysUtils, Classes, Graphics, Dialogs,
   ComCtrls, ExtCtrls, StdCtrls,  Math, StrUtils, ZConnection,
   ZDataset, ZAbstractRODataset, ZStoredProcedure, FuncColetor, DB, DBClient;


type
   gravacao = class(TThread)

   public

      //Parametros recebidos
      db_inserts  : Integer; //Insert Simultaneo
      db_hostname : String; //Nome do Host
      db_username : String; //Usuario
      db_database : String; //Database
      db_password : String; //Password
      ArqLog      : String;
      DirInbox    : String;
      DirProcess  : String;
      Encerrar    : Boolean;

      //Objetos
      Qry         : TZQuery;         //Um objeto query local
      conn        : TZConnection;    //Uma tconnection local
//      proc        : TZStoredProc;
      ArqPendentes : Integer;
      Arq_inbox    : String;

   private
     { Private declarations }
   protected

      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaDatabase;

   end;


implementation


// Execucao da Thread em si.
procedure gravacao.Execute;
begin

//   CarregaValores;
   Conn                 := TZConnection.Create(nil);
   Qry                  := TZQuery.Create(nil);
//   proc                 := TZStoredProc.Create(nil);

   conn.Properties.Add('CLIENT_MULTI_STATEMENTS=1');
   conn.Properties.Add('CLIENT_MULTI_RESULTS=1');
   conn.Properties.Add('compress=1');
   conn.Properties.Add('CLIENT_REMEMBER_OPTIONS=1');

   conn.HostName        := db_hostname;
   conn.User            := db_username;
   conn.Password        := db_password;
   conn.Database        := db_database;
   conn.Protocol        := 'mysql';
   conn.Port            := 3306;

   Try
      conn.Connect;
   Except
      SalvaLog(ArqLog,'Erro ao conectar com o MySql: ');
   End;

   Qry.Connection       := conn;

//   Proc.Connection      := conn;

//   Proc.StoredProcName  := 'gravar_acp245';
//   Proc.Params.CreateParam(ftBlob,'pcarg_dados',ptInput);
//   Proc.Params.CreateParam(ftString,'pcarg_ip',ptInput);
//   Proc.Params.CreateParam(ftInteger,'pcarg_porta',ptInput);
//   Proc.Params.CreateParam(ftString,'lID',ptOutPut);

   while Not Encerrar do
   Begin

      if Not conn.PingServer then
         Try
            conn.Connect;
         Except
            SalvaLog(ArqLog,'Erro ao conectar com o MySql: ' );
            Sleep(10000);
            Continue;
         End;

      if Not conn.Connected then
         Try
            conn.Connect;
         Except
            SalvaLog(ArqLog,'Erro ao "pingar" o MySql: ' );
            Sleep(10000);
            Continue;
         End;

      BuscaArquivo;

      if (Arq_inbox <> '') then
         GravaDatabase
      Else
      Begin
         Sleep(1000);
      End;

   End;

   Self.Free;

end;


Procedure gravacao.BuscaArquivo;
Var Arquivos: TSearchRec;
Begin

   ArqPendentes := 0;
   Arq_inbox := '';

   if FindFirst(DirInbox + '\*.rec', faAnyFile	, Arquivos) = 0 then
   begin
      Arq_inbox := DirInbox + '\' + arquivos.Name;
   End;

   FindClose(Arquivos);

End;


Procedure gravacao.GravaDatabase;
Var Processar  : TClientDataset;
    Processado : TClientDataset;
    Arq_Proce  : String;
    Erros      : Boolean;

Begin

   Erros := False;

   Processar := TClientDataset.Create(nil);
   Processar.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
   Processar.FieldDefs.Add('Datagrama', ftString, 1540, False);
   Processar.FieldDefs.Add('IP', ftString, 15, False);
   Processar.FieldDefs.Add('Porta', ftInteger, 0, False);
   Processar.FieldDefs.Add('ID', ftString, 20, False);
   Processar.CreateDataset;


   Processado := TClientDataset.Create(nil);
   Processado.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
   Processado.FieldDefs.Add('IP', ftString, 15, False);
   Processado.FieldDefs.Add('Porta', ftInteger, 0, False);
   Processado.FieldDefs.Add('ID', ftString, 20, False);
   Processado.CreateDataset;

   Try
      Processar.LoadFromFile(Arq_inbox);
   Except
      SalvaLog(ArqLog,'Arquivo não Encontrado: ' +  Arq_inbox );
   End;

   processar.First;

   while Not Processar.Eof do
   Begin
      Try

{         Proc.ParamByName('pcarg_dados').AsString  := Processar.FieldByName('DataGrama').AsString;
         Proc.ParamByName('pcarg_ip').AsString     := Processar.FieldByName('IP').AsString;
         Proc.ParamByName('pcarg_porta').AsInteger := Processar.FieldByName('Porta').AsInteger;
         Proc.ExecProc;
}
         Qry.Close;
         Qry.SQL.Clear;
         Qry.SQL.Add('call acp245.gravar_acp245(' + QuotedStr(Processar.FieldByName ('DataGrama').AsString) + ','  +
                                                    QuotedStr(Processar.FieldByName ('IP').AsString) + ',' +
                                                    Processar.FieldByName ('Porta').AsString + ');' ) ;
         Qry.Open;

         Processado.Insert;
         Processado.FieldByName('ID').AsString := Qry.Fields[0].AsString;
         Processado.FieldByName('IP').AsString := Processar.FieldByName('IP').AsString;
         Processado.FieldByName('Porta').AsString := Processar.FieldByName('Porta').AsString;
         Processado.FieldByName('Tcp_Client').AsString := Processar.FieldByName('Tcp_Client').AsString;
         Processado.Post;

         Processar.Delete;

      Except
         on E: Exception do
         begin
            SalvaLog(ArqLog,'Erro ao executar Procedure: ' + E.Message);
            Erros := True;
            processar.Last;
         end;

      End;
   End;

   processar.Close;

   Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_inbox);

   Try
      Processado.SaveToFile(Arq_Proce);
   Except
      SalvaLog(ArqLog,'Erro ao Salvar Processado: ' +  Arq_Proce);
   End;

   Try
      If not Erros Then
         deletefile(Arq_inbox);
   Except
      SalvaLog(ArqLog,'Erro ao Deletar recebidos: ' +  Arq_inbox);
   End;

End;
end.



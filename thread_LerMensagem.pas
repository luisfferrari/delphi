unit thread_LerMensagem;

interface

uses
   Windows, SysUtils, Classes, DB, DBClient,
   ZConnection, ZDataset, ZAbstractRODataset,
   FuncColetor;


type

   LerMensagem = class(TThread)

   public

      //Parametros recebidos
      db_hostname : String; //Nome do Host
      db_username : String; //Usuario
      db_database : String; //Database
      db_password : String; //Password
      DirMens     : String;
      Arq_Log     : String;
      ArqMens     : String;
      PortaLocal  : String;
      Debug       : Integer;
      Encerrar    : Boolean;
      Srv_Equipo  : String;   // Nome do protocolo a escutar / processar

      //Objetos
      Qry         : TZReadOnlyQuery; //Um objeto query local
      conn        : TZConnection;    //Uma tconnection local

      Arq_mens    : String;
      Mensagens   : TClientDataset;

   private
     { Private declarations }
   protected

      procedure Execute; override;
      Procedure BuscaMensagem;
      Procedure EnviaMensagem;
      Procedure AtualizaEnvio;
      Procedure Dormir(pTempo: Word);
   end;


implementation
Uses Gateway_01;


// Execucao da Thread em si.
procedure LerMensagem.Execute;
begin

Try

//   CarregaValores;
   Conn                 := TZConnection.Create(nil);
   Qry                  := TZReadOnlyQuery.Create(nil);

   conn.Properties.Add('compress=1');

   conn.HostName        := db_hostname;
   conn.User            := db_username;
   conn.Password        := db_password;
   conn.Database        := db_database;
   conn.Protocol        := 'mysql';
   conn.Port            := 3306;

   Qry.Connection       := conn;

   Try
      conn.Connect;
   Except
      SalvaLog(Arq_Log,'Thread LerMensagem - Erro ao conectar com o MySql: ');
   End;

   Mensagens := TClientDataset.Create(nil);
   Mensagens.FieldDefs.Add('ID', ftString, 20, False);
   Mensagens.FieldDefs.Add('Sequencia', ftInteger, 0, False);
   Mensagens.FieldDefs.Add('Mensagem', ftString, 1500, False);
   Mensagens.FieldDefs.Add('Status', ftInteger, 0, False);
   Mensagens.CreateDataset;

   while Not Encerrar do
   Begin
      if Srv_Equipo = 'WEBTECH' then
         TcpSrvForm.ThMsgWebTech_ultimo := Now
      Else
         TcpSrvForm.ThMsgAcp245_ultimo := Now;


      if Not conn.PingServer then
         Try
            conn.Disconnect;
            conn.Connect;
         Except
            SalvaLog(Arq_Log,'Thread LerMensagem - Erro ao "pingar" o MySql: ' );
            Dormir(30000);
            Continue;
         End;

      if Not conn.Connected then
         Try
            conn.Disconnect;
            conn.Connect;
         Except
            SalvaLog(Arq_Log,'Thread LerMensagem - Erro ao Conectar com o MySql: ' );
            Dormir(30000);
            Continue;
         End;

      BuscaMensagem;

      if (Mensagens.RecordCount > 0) then
      Begin
         Synchronize(EnviaMensagem);
         AtualizaEnvio;
      End;

      Dormir(10000);

   End;

   //SalvaLog(Arq_Log,'Thread Ler Mensagem - Encerrada' );
   Encerrar := True;
   Conn.Free;
   Qry.Free;
   Free;

Except

   //SalvaLog(Arq_Log,'ERRO - Thread Ler Mensagem - Encerrada' );
   Encerrar := True;
   Self.Free;

End;

Encerrar := True;
Self.Free;

end;


Procedure LerMensagem.BuscaMensagem;
Begin

   Mensagens.EmptyDataSet;

   try

      Qry.Close;
      Qry.Sql.Clear;
      Qry.SQL.Add('Select * from corp.comandos_envio Where porta = '  + PortaLocal + ' and status = 0;');
      Qry.Open;

      while Not Qry.Eof do
      Begin
         Mensagens.Append;
         Mensagens.FieldByName('ID').AsString := Qry.FieldByName('ID').AsString;
         Mensagens.FieldByName('Sequencia').AsInteger := Qry.FieldByName('Sequencia').AsInteger;
         Mensagens.FieldByName('Mensagem').AsString := Qry.FieldByName('comando').AsString;
         Mensagens.FieldByName('Status').AsInteger := 0;
         Mensagens.Post;
         Qry.Next;
      End;

      If Debug in [4,5,9] Then
         SalvaLog(Arq_Log,'Numero de mensagens lidas a enviar:  ' + InttoStr(Mensagens.RecordCount));

   Except
      SalvaLog(Arq_Log,'Erro ao ler mensagens no Banco de dados: ' );
   end;

   Sleep(10);

End;


Procedure LerMensagem.EnviaMensagem;

Begin

   Try

      If Not TcpSrvForm.EnviaMsgWebTech(Mensagens) Then
         If Debug in [4,5,9] Then
            SalvaLog(Arq_Log,IntToStr(Mensagens.RecordCount) +  ' Mensagens N�o Enviadas desconectado ? ');

   Except
      SalvaLog(Arq_Log,'Erro ao Enviar Mensagens: ' +  ArqMens);
   End;

End;

Procedure LerMensagem.AtualizaEnvio;
Var SqlExec: String;
Begin

   Mensagens.First;

   while Not Mensagens.Eof do
   try

      If Mensagens.FieldByName('Status').Asinteger = 3 Then
      Begin

         SqlExec := 'Update corp.comandos_envio Set Status = 3' +
                    ' Where id = ' + QuotedStr(Mensagens.FieldByName('Id').AsString) +
                    ' and Sequencia = ' + Mensagens.FieldByName('Sequencia').AsString +
                    ' and Status = 0;' + Char(13) + Char(10);

         if ExecutarSql(SqlExec, Arq_Log, Qry) Then
         Begin
            if Debug in [4,5,9]  then
               SalvaLog(Arq_Log,'Salvo no Banco o Envio: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ')');
            Mensagens.Delete;
         End
         Else
         Begin
            SalvaLog(Arq_Log,'N�o achou no Banco a Mensagem enviada: (ID/Sequencia): (' + Mensagens.FieldByName('ID').AsString + ':' + Mensagens.FieldByName('Sequencia').AsString + ')');
            Mensagens.Next;
         End;

      End
      Else
         Mensagens.Next;

   Except

      SalvaLog(Arq_Log,'Erro ao Atualizar mensagens enviadas: ' );

   end;


End;

Procedure LerMensagem.Dormir(pTempo: Word);
Var Contador: Word;
// Roda o Sleep em slice de 1/20 para checar o Final da thread
Begin
   For Contador := 1 to 20 do
   Begin
      if Not Encerrar then
         Sleep(Trunc(pTempo/20));
   End
End;

end.



unit thread_msgsatlight;

interface

uses
   Windows, SysUtils, Classes, DB, DBClient, ZConnection, ZDataset,
   ZAbstractRODataset,
   FuncColetor;

type

   msgSatlight = class(TThread)

   public

      // Parametros recebidos
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      DirMens: String;
      Arq_Log: String;
      ArqMens: String;
      PortaLocal: String;
      Debug: Integer;
      Encerrar: Boolean;
      Srv_Equipo: String; // Nome do protocolo a escutar / processar

      // Objetos
      Qry: TZReadOnlyQuery; // Um objeto query local
      conn: TZConnection; // Uma tconnection local

      Arq_mens: String;
      Mensagens: TClientDataset;

   private
      { Private declarations }
   protected

//      WSocketUdpEnv: TWSocket;

      procedure Execute; override;
      Procedure BuscaMensagem;
      Procedure EnviaMensagem;
      Procedure AtualizaEnvio;
      Procedure Dormir(pTempo: Word);
   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure msgSatlight.Execute;
begin

   Try

      conn := TZConnection.Create(nil);
      Qry := TZReadOnlyQuery.Create(nil);
//      WSocketUdpEnv := TWSocket.Create(TcpSrvForm);

      conn.Properties.Add('compress=1');

      conn.HostName := db_hostname;
      conn.User := db_username;
      conn.Password := db_password;
      conn.Database := db_database;
      conn.Protocol := 'mysql';
      conn.Port := 3306;
      Qry.Connection := conn;
      conn.Properties.Add('sort_buffer_size=4096');
      conn.Properties.Add('join_buffer_size=64536');

      Try
         conn.Connect;
      Except
         SalvaLog(Arq_Log,
            'Thread LerMensagem - Erro ao conectar com o MySql: ');
      End;

      Mensagens := TClientDataset.Create(nil);
      Mensagens.FieldDefs.Add('ID', ftString, 20, False);
      Mensagens.FieldDefs.Add('IP_REMOTO', ftString, 20, False);
      Mensagens.FieldDefs.Add('PORTA_REMOTO', ftInteger, 0, False);
      Mensagens.FieldDefs.Add('Sequencia', ftInteger, 0, False);
      Mensagens.FieldDefs.Add('Mensagem', ftString, 1500, False);
      Mensagens.FieldDefs.Add('Status', ftInteger, 0, False);
      Mensagens.CreateDataset;

      while Not Encerrar do
      Begin

         TcpSrvForm.ThMsgSatLight_ultimo := Now;

         if Not conn.PingServer then
            Try
               conn.Disconnect;
               conn.Connect;
            Except
               SalvaLog(Arq_Log,
                  'Thread LerMensagem - Erro ao "pingar" o MySql: ');
               Dormir(30000);
               Continue;
            End;

         if Not conn.Connected then
            Try
               conn.Disconnect;
               conn.Connect;
            Except
               SalvaLog(Arq_Log,
                  'Thread LerMensagem - Erro ao Conectar com o MySql: ');
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

      // SalvaLog(Arq_Log,'Thread Ler Mensagem - Encerrada' );
      Encerrar := True;
//      WSocketUdpEnv.Release;
      Qry.Close;
      conn.Disconnect;
      Qry.Free;
      conn.Free;
      Self.Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Mensagem SatLight - Encerrada por Erro: '
         + InttoStr(ThreadId));
      Encerrar := True;
      Self.Free;

   End;

end;

Procedure msgSatlight.BuscaMensagem;
Var
   StrSql: String;
   Comando: String;
Begin

   Mensagens.EmptyDataSet;

   try

      StrSql := 'Select msg.*, pos.ip_remoto, pos.porta_remoto ';
      StrSql := StrSql + 'from Nexsat.comandos_envio msg ';
      StrSql := StrSql + 'Inner Join nexsat.posicoes_lidas pos ';
      StrSql := StrSql + ' on msg.id = pos.id ';
      StrSql := StrSql + 'Where msg.porta = ' + PortaLocal +
         ' and msg.status = 0;';

      Qry.Close;
      Qry.Sql.Clear;
      Qry.Sql.Add(StrSql);
      Qry.Open;

      while Not Qry.Eof do
      Begin

         Comando := '0000';
         Comando := Comando + Qry.FieldByName('ID').AsString;;
         Comando := Comando + FormatFloat('000000', Qry.FieldByName('Sequencia')
            .AsInteger);
         Comando := Comando + Qry.FieldByName('comando').AsString;

         Mensagens.Append;
         Mensagens.FieldByName('ID').AsString := Qry.FieldByName('ID').AsString;
         Mensagens.FieldByName('IP_REMOTO').AsString :=
            Qry.FieldByName('IP_REMOTO').AsString;
         Mensagens.FieldByName('PORTA_REMOTO').AsInteger :=
            Qry.FieldByName('PORTA_REMOTO').AsInteger;
         Mensagens.FieldByName('Sequencia').AsInteger :=
            Qry.FieldByName('Sequencia').AsInteger;
         Mensagens.FieldByName('Mensagem').AsString := Comando;
         Mensagens.FieldByName('Status').AsInteger := 0;
         Mensagens.Post;

         {
           WSocketUdpEnv.Close;
           WSocketUdpEnv.Proto      := 'udp';
           WSocketUdpEnv.Addr       := Mensagens.FieldByName('IP_REMOTO').AsString;
           WSocketUdpEnv.Port       := Mensagens.FieldByName('PORTA_REMOTO').AsString;
           WSocketUdpEnv.Connect;
           WSocketUdpEnv.SendStr(Comando);
           SalvaLog(Arq_Log,'Mensagem Enviada: ' + Mensagens.FieldByName('IP_REMOTO').AsString + ':' + Mensagens.FieldByName('PORTA_REMOTO').AsString + ' - ' + Comando);
         }
         Sleep(10);

         Qry.Next;

      End;

      If (Debug in [4, 5, 9]) and (Mensagens.RecordCount > 0) Then
         SalvaLog(Arq_Log, 'Numero de mensagens lidas a enviar:  ' +
            InttoStr(Mensagens.RecordCount));

   Except
      SalvaLog(Arq_Log, 'Erro ao ler mensagens no Banco de dados: ' + StrSql);
   end;

   Sleep(50);

End;

Procedure msgSatlight.EnviaMensagem;

Begin

   Try

      If Not TcpSrvForm.EnviaMsgSatLight(Mensagens) Then
         If Debug in [4, 5, 9] Then
            SalvaLog(Arq_Log, InttoStr(Mensagens.RecordCount) +
               ' Mensagens Não Enviadas desconectado ? ');

   Except
      SalvaLog(Arq_Log, 'Erro ao Enviar Mensagens: ' + ArqMens);
   End;

End;

Procedure msgSatlight.AtualizaEnvio;
Var
   SqlExec: String;
Begin

   Mensagens.First;

   while Not Mensagens.Eof do
      try

         If Mensagens.FieldByName('Status').AsInteger = 3 Then
         Begin

            SqlExec := 'Update Nexsat.comandos_envio Set Status = 1' +
               ' Where id = ' + QuotedStr(Mensagens.FieldByName('Id').AsString)
               + ' and Sequencia = ' + Mensagens.FieldByName('Sequencia')
               .AsString + ' and Status = 0;' + Char(13) + Char(10);

            if ExecutarSql(SqlExec, Arq_Log, Qry) Then
            Begin
               if Debug in [4, 5, 9] then
                  SalvaLog(Arq_Log, 'Salvo no Banco o Envio: (ID/Sequencia): ('
                     + Mensagens.FieldByName('ID').AsString + ':' +
                     Mensagens.FieldByName('Sequencia').AsString + ')');
               Mensagens.Delete;
            End
            Else
            Begin
               SalvaLog(Arq_Log,
                  'Não achou no Banco a Mensagem enviada: (ID/Sequencia): (' +
                  Mensagens.FieldByName('ID').AsString + ':' +
                  Mensagens.FieldByName('Sequencia').AsString + ')');
               Mensagens.Next;
            End;

         End
         Else
            Mensagens.Next;

      Except

         SalvaLog(Arq_Log, 'Erro ao Atualizar mensagens enviadas: ');

      end;

End;

Procedure msgSatlight.Dormir(pTempo: Word);
Var
   Contador: Word;
   // Roda o Sleep em slice de 1/20 para checar o Final da thread
Begin
   For Contador := 1 to 20 do
   Begin
      if Not Encerrar then
         Sleep(Trunc(pTempo / 20));
   End
End;

end.

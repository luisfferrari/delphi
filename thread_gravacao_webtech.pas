unit thread_gravacao_webtech;

interface

uses
   Windows, SysUtils, Classes, Math, StrUtils,
   DB, DBClient, FuncColetor;

Type

   gravacao_webtech = class(TThread)
   public

      // Parametros recebidos
      db_inserts: Integer; // Insert Simultaneo
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      Arq_Log: String;
      Arq_Err: String;
      Arq_Sql: String;
      DirInbox: String;
      DirProcess: String;
      DirErros: String;
      DirSql: String;
      PortaLocal: Integer;
      Encerrar: Boolean;
      Debug: SmallInt;
      ThreadId: Word;

      // Objetos
//      Qry: TZReadOnlyQuery; // Um objeto query local
//      conn: TZConnection; // Uma tconnection local
      ArqPendentes: Integer;
      Arq_inbox: String;
      Pacote: Pack_Webtech;
      SqlTracking: String;
      SqlResposta: String;

   private
      { Private declarations }
      Processar: tClientDataSet;
   protected

      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaDatabase;
      Function Decode(pPacket: String): SmallInt;
      Procedure LimpaRecord();
      Procedure Dormir(pTempo: Word);
   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure gravacao_webtech.Execute;
begin
   Try
      FreeOnTerminate := True;
      SqlTracking :=
         'Insert into nexsat.Posicoes_carga ( ANGULO, ATUALIZADO, AUX1, AUX2, AUX3, AUX4, AUX5, AUX6, '
         + 'AUX7, AUX8, BATERIA, BATTERYPRESENT, CHAVE, DH_GPS, HORIMETRO, ID, '
         + 'IP_REMOTO, LATITUDE, LONGITUDE, MARC_CODIGO, ODOMETRO, PANICO1, PORTA, PORTA_REMOTO, QTDADE_SATELITE, '
         + 'SAI_1, SAI_2, SAI_3, SAI_4, SAI_5, SAI_6, SAI_7, SAI_8, ' +
         'V4ANTOPEN, V4ANTSHORT, VELOCIDADE) ';

      //conn := TZConnection.Create(nil);
      //Qry := TZReadOnlyQuery.Create(nil);

      //conn.Properties.Add('compress=1');
      //conn.Properties.Add('CLIENT_REMEMBER_OPTIONS=1');

      //conn.HostName := db_hostname;
      //conn.User := db_username;
      //conn.Password := db_password;
      //conn.Database := db_database;
      //conn.Protocol := 'mysql';
      //conn.Port := 3306;
      //Qry.Connection := conn;

      //conn.Properties.Add('sort_buffer_size=4096');
      //conn.Properties.Add('join_buffer_size=64536');


      //Try
      //   conn.Connect;
      //Except
      //   SalvaLog(Arq_Log,
      //      'Thread Gravação Webtech - Erro ao conectar com o MySql: ');
      //End;

      Processar := tClientDataSet.Create(nil);
      Processar.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processar.FieldDefs.Add('IP', ftString, 15, False);
      Processar.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processar.FieldDefs.Add('ID', ftString, 20, False);
      Processar.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Processar.FieldDefs.Add('Datagrama', ftString, 1540, False);
      Processar.FieldDefs.Add('Processado', FtBoolean, 0, False);
      Processar.CreateDataSet;

      while Not Encerrar do
      Begin

         TcpSrvForm.Thgravacao_webtech_ultimo := Now;

         //if Not conn.PingServer then
         //   Try
         //      conn.Disconnect;
         //      conn.Connect;
         //   Except
         //      SalvaLog(Arq_Log,
         //         'Thread Gravação Webtech - Erro ao "pingar" o MySql: ');
         //      Dormir(30000);
         //      Continue;
         //   End;

         //if Not conn.Connected then
         //   Try
         //      conn.Disconnect;
         //      conn.Connect;
         //   Except
         //      SalvaLog(Arq_Log,
         //         'Thread Gravação Webtech - Erro ao Conectar com o MySql: ');
         //      Dormir(30000);
         //      Continue;
         //   End;

         Sleep(100);

         BuscaArquivo;

         if (Arq_inbox <> '') then
            GravaDatabase
         Else
         Begin
            Dormir(500);
         End;

      End;

      // SalvaLog(Arq_Log,'Thread Gravação Webtech - Encerrada' );
      //Qry.Close;
      //conn.Disconnect;
      //Qry.Free;
      //conn.Free;
      Self.Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Gravação Webtech - Encerrada por Erro: '
         + InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;

end;

Procedure gravacao_webtech.BuscaArquivo;
Var
   Arquivos: TSearchRec;
Begin
   Try
      ArqPendentes := 0;
      Arq_inbox := '';

      if FindFirst(DirInbox + '\*.WEB' + FormatFloat('00', ThreadId), faArchive,
         Arquivos) = 0 then
      begin
         Arq_inbox := DirInbox + '\' + Arquivos.Name;
         Arq_Sql   := DirSql   + '\' + ExtractFileName(Arq_inbox);
         Arq_Err   := DirErros + '\' + ExtractFileName(Arq_inbox);
      End;

      FindClose(Arquivos);
      Sleep(50);

   Except
      Arq_inbox := '';
   End;

End;

Procedure gravacao_webtech.GravaDatabase;
Var
   TipoPacket: Integer;
   SqlExec: String;
   ContErro: Integer;
   ContTrack: Integer;
   ContMsg: Integer;
   SqlPendente: String;

Begin
   Try
      if Debug in [2, 5, 9] then
         SalvaLog(Arq_Log, 'Vai Processar o Arquivo:' + Arq_inbox);

      ContTrack   := 0;
//      ContMsg     := 0;
      ContErro    := 0;
      SqlPendente := '';

      Try
         Processar.LoadFromFile(Arq_inbox);
      Except
         SalvaLog(Arq_Log, 'Arquivo não Encontrado: ' + Arq_inbox);
         Exit;
      End;

      Processar.First;

      while Not Processar.Eof do
      Begin

         Try

            if Debug in [2, 5, 9] then
               SalvaLog(Arq_Log, 'Datagrama Recebido:' +
                  Processar.FieldByName('DataGrama').AsString);

            LimpaRecord;

            TipoPacket := Decode(Processar.FieldByName('DataGrama').AsString);

            if Debug in [9] then
               SalvaLog(Arq_Log, 'ID:Tipo de pacote:' + Processar.FieldByName
                  ('ID').AsString + ':' + InttoStr(TipoPacket));

            // Se for pacote de tracking
            if TipoPacket = 1 then
            Begin

               SqlExec := SqlTracking;
               SqlExec := SqlExec + ' Values(';

               SqlExec := SqlExec + InttoStr(Pacote.Angulo) + ',';
               SqlExec := SqlExec + InttoStr(Pacote.Atualizado) + ',';
               SqlExec := SqlExec + Pacote.Aux1 + ',';
               SqlExec := SqlExec + Pacote.Aux2 + ',';
               SqlExec := SqlExec + Pacote.Aux3 + ',';
               SqlExec := SqlExec + Pacote.Aux4 + ',';
               SqlExec := SqlExec + Pacote.Aux5 + ',';
               SqlExec := SqlExec + Pacote.Aux6 + ',';
               SqlExec := SqlExec + Pacote.Aux7 + ',';
               SqlExec := SqlExec + Pacote.Aux8 + ',';
               SqlExec := SqlExec + Pacote.Bateria + ',';
               SqlExec := SqlExec + Pacote.BatteryPresent + ',';
               SqlExec := SqlExec + Pacote.Chave + ',';
               SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(Pacote.DH_GPS) +
                  ',INTERVAL   hour(timediff(now(),utc_timestamp())) Hour),';
               SqlExec := SqlExec + InttoStr(Pacote.Horimetro) + ',';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('ID')
                  .AsString) + ',';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('IP')
                  .AsString) + ',';
               SqlExec := SqlExec + Copy(troca(FloatToStr(Pacote.Latitude)), 1,
                  15) + ',';
               SqlExec := SqlExec + Copy(troca(FloatToStr(Pacote.Longitude)), 1,
                  15) + ',';
               SqlExec := SqlExec + InttoStr(Pacote.Marc_codigo) + ',';
               SqlExec := SqlExec + InttoStr(Pacote.Odometro) + ',';
               SqlExec := SqlExec + Pacote.Panico1 + ',';
               SqlExec := SqlExec + InttoStr(PortaLocal) + ',';
               SqlExec := SqlExec + Processar.FieldByName('Porta')
                  .AsString + ',';
               SqlExec := SqlExec + InttoStr(Pacote.Qtdade_Satelite) + ',';
               SqlExec := SqlExec + Pacote.Sai1 + ',';
               SqlExec := SqlExec + Pacote.Sai2 + ',';
               SqlExec := SqlExec + Pacote.Sai3 + ',';
               SqlExec := SqlExec + Pacote.Sai4 + ',';
               SqlExec := SqlExec + Pacote.Sai5 + ',';
               SqlExec := SqlExec + Pacote.Sai6 + ',';
               SqlExec := SqlExec + Pacote.Sai7 + ',';
               SqlExec := SqlExec + Pacote.Sai8 + ',';
               SqlExec := SqlExec + Pacote.V4AntOpen + ',';
               SqlExec := SqlExec + Pacote.V4AntShort + ',';
               SqlExec := SqlExec + InttoStr(Pacote.Velocidade) + ');';

               SqlPendente := SqlPendente +  SqlExec + Chr(13) + Chr(10);

               if Debug in [2, 5, 9] then
                  SalvaLog(Arq_Log, 'Vai executar no Banco:' + SqlExec);

               Processar.Delete;
               Inc(ContTrack);

            End
            Else if TipoPacket = 2 then // Pacote de mensagem recebida
            Begin

               SqlExec := 'Call nexsat.recebe_parametros(' +
                  QuotedStr(Processar.FieldByName('ID').AsString) + ',' +
                  QuotedStr(Trim(Pacote.Mensagem)) + ');';

               SqlPendente := SqlPendente +  SqlExec + Chr(13) + Chr(10);

               SqlExec :=
                  'Update nexsat.comandos_envio Set Status = 3 Where id = ' +
                  QuotedStr(Processar.FieldByName('ID').AsString) +
                  ' and sequencia = ' + Processar.FieldByName('MsgSequencia')
                  .AsString + ';';

               SqlPendente := SqlPendente +  SqlExec + Chr(13) + Chr(10);

               Processar.Delete;

            End
            Else if TipoPacket = 3 then
            Begin

               SqlExec :=
                  'Update nexsat.comandos_envio Set Status = 0 Where id = ' +
                  QuotedStr(Processar.FieldByName('ID').AsString) +
                  ' and Status = 1;';

               SqlPendente := SqlPendente +  SqlExec + Chr(13) + Chr(10);
               Processar.Delete;

            End
            Else if TipoPacket = 4 then
            Begin
               SqlExec :=
                  'Update nexsat.comandos_envio Set Status = 3 Where id = ' +
                  QuotedStr(Processar.FieldByName('ID').AsString) +
                  ' and sequencia = ' + Processar.FieldByName('MsgSequencia')
                  .AsString + ';';

               Inc(ContMsg);

               SqlPendente := SqlPendente +  SqlExec + Chr(13) + Chr(10);
               Processar.Delete;

            End
            Else if TipoPacket = 0 then
            Begin
               Processar.Next;
               Inc(ContErro);
               Continue;
            End;

         Except

            on E: Exception do
            begin
               SalvaLog(Arq_Log, 'Erro ao executar Gravação no Banco: ' + E.Message + ' : ' + SqlExec);
               Inc(ContErro);
               Processar.Next;
            end;

         End;


      End;

      Try
         If (ContErro = 0) Then
         Begin
            SalvaArquivo(Arq_Sql, SqlPendente);
            Processar.Close;
            deletefile(Arq_inbox);
         End
         Else
         Begin
            Processar.SaveToFile(Arq_Err);
            SalvaLog(Arq_Log, 'Erro ao Deletar recebidos/ Gravar SQL: ' + Arq_inbox);
            deletefile(Arq_inbox);
         End;
      Except
         Processar.SaveToFile(Arq_Err);
         SalvaLog(Arq_Log, 'Erro ao Deletar recebidos/ Gravar SQL: ' + Arq_inbox);
         deletefile(Arq_inbox);
      End;

      Sleep(10);

   Except
      SalvaLog(Arq_Log, 'Erro na Procedure GravaDatabase: ' + Arq_inbox);
   End;
End;

Function gravacao_webtech.Decode(pPacket: String): SmallInt;
Var
   Strproc: String;
   Separador: String;
Begin
   Result := 0;
   Try
      Separador := ',';
      LimpaRecord;

      // Pacote de Login
      if Pos('login', pPacket) > 0 Then
      Begin
         Result := 3;
      End
      // Linha de tracking
      Else if Pos('L3,01,', pPacket) > 0 then
      Begin

         // Limpa o começo da String
         StringProcessar(pPacket, Strproc, Separador);
         StringProcessar(pPacket, Strproc, Separador);

         // Latitude
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Latitude := hms_to_latitude(Strproc);
         if Debug in [9] then
            SalvaLog(Arq_Log, 'Latitude:' + FloatToStr(Pacote.Latitude));

         // Longitude
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Longitude := hms_to_longitude(Strproc);
         if Debug in [9] then
            SalvaLog(Arq_Log, 'Longitude:' + FloatToStr(Pacote.Longitude));

         // Velocidade e direcao
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Velocidade := ParaInteiro(Copy(Strproc, 1, 3));
         Pacote.Angulo := ParaInteiro(Copy(Strproc, 4, 3));
         if Debug in [9] then
         Begin
            SalvaLog(Arq_Log, 'Velocidade:' + InttoStr(Pacote.Velocidade));
            SalvaLog(Arq_Log, 'Angulo:' + InttoStr(Pacote.Angulo));
         End;

         // Data Hora - TimeStamp - Se a hora for zerada, assume a atual. Infelizmente !
         StringProcessar(pPacket, Strproc, Separador);
         if Strproc = '00000000000000' then
            Pacote.DH_GPS := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now)
         Else
            Try
               Pacote.DH_GPS := Copy(Strproc, 1, 4) + '-' + Copy(Strproc, 5, 2)
                  + '-' + Copy(Strproc, 7, 2) + ' ' + Copy(Strproc, 9, 2) + ':'
                  + Copy(Strproc, 11, 2) + ':' + Copy(Strproc, 13, 2);
            Except
               Pacote.DH_GPS := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
            End;
         if Debug in [9] then
            SalvaLog(Arq_Log, 'Dh_Gps:' + Pacote.DH_GPS);

         // Gps Atualizado
         StringProcessar(pPacket, Strproc, Separador);
         Try
            if Strproc[3] = 'F' then
               Pacote.Atualizado := 1
            Else
               Pacote.Atualizado := 0;
         Except
            Pacote.Atualizado := 0;
         End;
         if Debug in [9] then
            SalvaLog(Arq_Log, 'Flag GPS:' + Strproc);

         // Crossings
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.QtCerca := Strproc;
         if Debug in [9] then
            SalvaLog(Arq_Log, 'Crossings:' + Strproc);

         // Odometro
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Odometro := ParaInteiro(Strproc);
         if Pacote.Odometro < 0  then
            Pacote.Odometro := 0;

         if Debug in [9] then
            SalvaLog(Arq_Log, 'Odometro:' + Strproc);

         // Horimetro
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Horimetro := Round(ParaInteiro(Strproc) / 60);
         if Debug in [9] then
            SalvaLog(Arq_Log, 'Horimetro:' +
               InttoStr(Round(ParaInteiro(Strproc) / 60)));

         // ADC
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Adc := Strproc;
         if Debug in [9] then
            SalvaLog(Arq_Log, 'ADC:' + Strproc);

         // Entradas
         StringProcessar(pPacket, Strproc, Separador);
         Strproc := HexToStrBitsInverted(Strproc, True);
         Pacote.Aux4 := Strproc[5];
         Pacote.Aux5 := Strproc[6];
         Pacote.Aux6 := Strproc[7];
         Pacote.Aux8 := Strproc[9];
         Pacote.Aux9 := Strproc[10];
         Pacote.Panico1 := Strproc[5];
         Pacote.Chave := Strproc[2];
         Pacote.V4AntOpen := Strproc[1];
         Pacote.V4AntShort := Strproc[11];
         Pacote.Bateria := Strproc[12];
         Pacote.BatteryPresent := Strproc[13];
         if (Pacote.Chave = '1') and (Pacote.Aux1 = '1') then
            Pacote.Panico2 := '1';

         if Debug in [9] then
            SalvaLog(Arq_Log, 'Entradas:' + Strproc);

         // Saidas
         StringProcessar(pPacket, Strproc, Separador);
         Strproc := HexToStrBitsInverted(Strproc, False);
         Pacote.Sai7 := Strproc[8];
         Pacote.Sai8 := Strproc[9];
         Pacote.Sai9 := Strproc[10];
         Pacote.Sai10 := Strproc[11];
         Pacote.Sai11 := Strproc[12];
         Pacote.Sai12 := Strproc[13];
         if Debug in [9] then
            SalvaLog(Arq_Log, 'Saidas:' + Strproc);

         // RSSI
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Rssi := Strproc;
         if Debug in [9] then
            SalvaLog(Arq_Log, 'RSSI:' + Strproc);

         // Qtdade_Satelites
         StringProcessar(pPacket, Strproc, Separador);
         Pacote.Qtdade_Satelite := ParaInteiro(Strproc);

         if Debug in [9] then
            SalvaLog(Arq_Log, 'Qtd Satelites:' + Strproc);

         // Pacote de tracking Lido com sucesso
         Result := 1;

      End
      // Pacote de Mensagem Solicitada recebida. Ignorar
      Else If (Copy(pPacket, 1, 15) = 'C0 sendloc:SENT') and
         (Length(pPacket) < 20) then
      Begin
         Result := 4;
      End
      // Pacote de Mensagem
      Else if Pos('C0', pPacket) > 0 then
      Begin
         Pacote.Mensagem := pPacket;

         Result := 2;
      End
      Else
         SalvaLog(Arq_Log, 'Pacote inválido:' + pPacket);

   Except
      SalvaLog(Arq_Log, 'Erro ao executar decode:' + pPacket);
   End;
End;

Procedure gravacao_webtech.LimpaRecord();
Begin
   Pacote.Adc := '';
   Pacote.Angulo := 0;
   Pacote.Atualizado := 0;
   Pacote.Aux1 := '0';
   Pacote.Aux2 := '0';
   Pacote.Aux3 := '0';
   Pacote.Aux4 := '0';
   Pacote.Aux5 := '0';
   Pacote.Aux6 := '0';
   Pacote.Aux7 := '0';
   Pacote.Aux8 := '0';
   Pacote.Aux9 := '0';
   Pacote.Bateria := '0';
   Pacote.BatteryPresent := '0';
   Pacote.Chave := '0';
   Pacote.DH_GPS := '';
   Pacote.Extension := '';
   Pacote.Horimetro := 0;
   Pacote.Id := '';
   Pacote.Latitude := 0;
   Pacote.Longitude := 0;
   Pacote.Marc_codigo := 20;
   Pacote.Mensagem := '';
   Pacote.Odometro := 0;
   Pacote.Panico1 := '0';
   Pacote.Panico2 := '0';
   Pacote.QtCerca := '';
   Pacote.Qtdade_Satelite := 0;
   Pacote.Rssi := '';
   Pacote.Sai1 := '0';
   Pacote.Sai2 := '0';
   Pacote.Sai3 := '0';
   Pacote.Sai4 := '0';
   Pacote.Sai5 := '0';
   Pacote.Sai6 := '0';
   Pacote.Sai7 := '0';
   Pacote.Sai8 := '0';
   Pacote.Sai9 := '0';
   Pacote.Sai10 := '0';
   Pacote.Sai11 := '0';
   Pacote.Sai12 := '0';
   Pacote.Sbas := '';
   Pacote.Status := '';
   Pacote.V4AntOpen := '0';
   Pacote.V4AntShort := '0';
   Pacote.Velocidade := 0;

End;

Procedure gravacao_webtech.Dormir(pTempo: Word);
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

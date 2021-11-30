unit thread_gravacao_quanta_acp;

interface

uses
   Windows, SysUtils, Classes, Math, DB, DBClient, Types,
   // ZConnection, ZDataset, ZAbstractRODataset, ZSqlProcessor,
   DateUtils, FuncColetor, FunAcp;

type
   Gravacao_Quanta_Acp = class(TThread)

   public

      // Parametros recebidos
      db_inserts: Integer; // Insert Simultaneo
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      db_tablecarga: String; // Nome da tabela de carga
      Arq_Log: String;
      DirInbox: String;
      DirProcess: String;
      DirErros: String;
      DirSql: String;
      ThreadId: Word;
      Encerrar: Boolean;
      Debug: Integer;
      Debug_ID: String;
      PortaLocal: Integer;
      ServerStartUp: tDateTime;
      Arq_inbox: String;
      // Objetos
      {
        QryBatch     : TZSqlProcessor;         //Um objeto query local
        QryStatus    : TZReadOnlyQuery;        //Um objeto query local
        conn         : TZConnection;           //Uma tconnection local
      }

   private
      { Private declarations }
      SqlTracking: String;
      SqlPendente: String;
      AcpHeader: tAcpHeader;
      AcpVersion: tAcpVersion;
      AcpTimeStamp: tAcpTimeStamp;
      AcpLocation: tAcpLocation;
      AcpGPS_Current: tAcpGPS_Current;
      AcpGPS_Current_Coding: tAcpGPS_Current_Coding;
      AcpGPS_Prior: tAcpGPS_Prior;
      AcpGPS_Prior_Coding: tAcpGPS_Prior_Coding;
      AcpCDRD_WGS84: tAcpCDRD_WGS84;
      AcpArea_Delta: tAcpArea_Delta;
      AcpVehicle: tAcpVehicle;
      AcpBreakDown: tAcpBreakDown;
      AcpInformation: tAcpInformation;
      AcpMessage: tAcpMessage;
      AcpControl_Function: tAcpControl_Function;
      AcpFunction_Command: tAcpFunction_Command;
      AcpError: tAcpError;
      AcpDataError: Array Of tAcpDataError;
      PacketStr: String;
      PacketTot: TByteDynArray;
      PacketRec: TByteDynArray;
      Resposta: TByteDynArray;
      PosInicio: Word;
      Corrigido: Word;
   protected

      Processar: tClientDataSet;
      Processado: tClientDataSet;
      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaTracking;
      Function Decode: SmallInt;
      Function Decode_App02_03(Var pInicial: SmallInt): SmallInt;
      Function Decode_App02_09(Var pInicial: SmallInt): SmallInt;
      Function Decode_App06(Var pInicial: SmallInt): SmallInt;
      Function Decode_App10(Var pInicial: SmallInt): SmallInt;
      Function Decode_App11(Var pInicial: SmallInt): SmallInt;
      Function Decode_Version(Var pInicial: SmallInt): SmallInt;
      Function Decode_TimeStamp(Var pInicial: SmallInt): SmallInt;
      Function Decode_Location(Var pInicial: SmallInt): SmallInt;
      Function Decode_Vehicle(Var pInicial: SmallInt): SmallInt;
      Function Decode_BreakDown(Var pInicial: SmallInt; pTipo_App: Integer): SmallInt;
      Function Decode_Information(Var pInicial: SmallInt): SmallInt;
      Function Decode_Message(Var pInicial: SmallInt): SmallInt;
      Function Decode_Control_Function(Var pInicial: SmallInt): SmallInt;
      Function Decode_Function_Command(Var pInicial: SmallInt): SmallInt;
      Function Decode_Error(Var pInicial: SmallInt): SmallInt;
      Function Decode_TCU_Data_Error(Var pInicial: SmallInt): SmallInt;
      Function Decode_Reserved(Var pInicial: SmallInt): SmallInt;
      Procedure ZeraRecord;
      Procedure Dormir(pTempo: SmallInt);

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure Gravacao_Quanta_Acp.Execute;
begin
   Try
      // CarregaValores;
      {
        Conn                 := TZConnection.Create(nil);
        QryBatch             := TZSqlProcessor.Create(Nil);
        QryStatus            := TZReadOnlyQuery.Create(Nil);
        conn.HostName        := db_hostname;
        conn.User            := db_username;
        conn.Password        := db_password;
        conn.Database        := db_database;
        conn.Protocol        := 'mysql';
        conn.Port            := 3306;
        QryBatch.Connection  := conn;
        QryStatus.Connection := conn;
      }
      // SqlTracking :=  'call acp245.gravar_acp245(:DataGrama, :IP, :Porta);';
      SqlTracking := 'insert into nexsat.' + db_tablecarga + ' ';
      SqlTracking := SqlTracking +
         '(id, dh_gps, latitude, longitude, porta, ip_remoto, porta_remoto, velocidade, angulo, qtdade_satelite, atualizado, chave, bateria_violada, bateria_religada, breakdown1, breakdown2, breakdown3, breakdown4, marc_codigo) ';

      {
        conn.Properties.Add('sort_buffer_size=65536');
      }

      Processar := tClientDataSet.Create(nil);
      Processar.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processar.FieldDefs.Add('IP', ftString, 15, False);
      Processar.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processar.FieldDefs.Add('ID', ftString, 20, False);
      Processar.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Processar.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Processar.FieldDefs.Add('Processado', ftBoolean, 0, False);
      Processar.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      Processar.CreateDataSet;

      Processado := tClientDataSet.Create(nil);
      Processado.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processado.FieldDefs.Add('IP', ftString, 15, False);
      Processado.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processado.FieldDefs.Add('ID', ftString, 20, False);
      Processado.FieldDefs.Add('Resposta', ftBlob, 0, False);
      Processado.CreateDataSet;

      {
        Try
        conn.Connect;
        Except
        SalvaLog(Arq_Log,'Erro ao conectar com o MySql: ');
        End;
      }
      while Not Encerrar do
      Begin

         Arq_Log := ExtractFileDir(Arq_Log) + '\' + FormatDateTime('yyyy-mm-dd',
            now) + '.log';

         TcpSrvForm.ThGravacao_Quanta_Acp_ultimo := now;

         {
           Try
           if (Not conn.PingServer) then
           Begin
           conn.Disconnect;
           conn.Connect;
           End;
           Except
           SalvaLog(Arq_Log,'Erro ao "pingar" o MySql: ' );
           Dormir(1000);
           Continue;
           End;

           if (Not conn.Connected) then
           Try
           conn.Disconnect;
           conn.Connect;
           Except
           SalvaLog(Arq_Log,'Erro ao conectar com o MySql: ' );
           Dormir(1000);
           Continue;
           End;
         }
         BuscaArquivo;

         if (Arq_inbox <> '') then
            GravaTracking
         Else
         Begin
            Dormir(50);
         End;

      End;

      {
        QryStatus.Close;
        conn.Disconnect;
        QryBatch.Free;
        QryStatus.Free;
        conn.Free;
      }
      Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Gravação ACP - Encerrada por Erro: ' +
         InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;
end;

Procedure Gravacao_Quanta_Acp.BuscaArquivo;
Var Arquivos: TSearchRec;
//Var Arq_sql_pendente: String;
//Var Arq_Sql: String;

Begin

   // Checa por arquivo Inbox de posicoes
   Arq_inbox := '';

   if FindFirst(DirInbox + '\*.ACP' + FormatFloat('00', ThreadId), faArchive,
      Arquivos) = 0 then
   begin
      Arq_inbox := DirInbox + '\' + Arquivos.Name;
   End;

   FindClose(Arquivos);

   Sleep(50);

End;

Procedure Gravacao_Quanta_Acp.GravaTracking;
Var
   Arq_Proce: String;
   Arq_Err: String;
   Arq_Sql: String;
   SqlExec: String;
   blobF: TBlobField;
   Stream: TMemoryStream;
   blobR: TBlobField;
   StreamRes: TMemoryStream;
   TipoPacket: SmallInt;
   erro: Boolean;
   FileDate: tDateTime;
   StrTmp: String;
   tInicio: tDateTime;
   tFinal: tDateTime;
   Contador: Word;
//   ContTrack: Word;
   ContErros: Word;
   BitsBreakDown: String;

Begin

   ContErros := 0;
//   ContTrack := 0;
   SqlPendente := '';
   Corrigido := 0;

   StrTmp := ExtractFileName(Arq_inbox);
   Try
      FileDate := EncodeDateTime(StrtoIntDef(Copy(StrTmp, 1, 4),0),
         StrtoIntDef(Copy(StrTmp, 6, 2),0), StrtoIntDef(Copy(StrTmp, 9, 2),0),
         StrtoIntDef(Copy(StrTmp, 12, 2),0), StrtoIntDef(Copy(StrTmp, 15, 2),0),
         StrtoIntDef(Copy(StrTmp, 18, 2),0), 0);
   Except
      FileDate := now;
   End;

   Try
      Processar.LoadFromFile(Arq_inbox);
   Except
      SalvaLog(Arq_Log, 'Arquivo não Encontrado: ' + Arq_inbox);
      Exit;
   End;

   Processar.First;

   If Not Processado.Active Then
      Processado.Open;

   Processado.EmptyDataSet;
   tInicio := now;

   while Not Processar.Eof do
   Begin

      erro := False;
      TipoPacket := 0;

      // Leitura do arquivo de recebidos
      Try

         Stream := TMemoryStream.Create;
         blobF := Processar.FieldByName('DataGrama') as TBlobField;

         try
            blobF.SaveToStream(Stream);
            StreamToByteArray(Stream, PacketTot);
         finally
            Stream.Free;
         end;

      Except
         SalvaLog(Arq_Log, 'Erro ao ler Blob: ');
         Inc(ContErros);
         Processar.Next;
         Continue;
      End;

      Try
         PacketStr := '';
         for Contador := 0 to Length(PacketTot) - 1 do
            PacketStr := PacketStr + IntToHex(PacketTot[Contador], 2);
      Except
         SalvaLog(Arq_Log, 'Pacote a ser decodificado: ZERADO !!!');
      End;
      while (Not erro) and (Length(PacketTot) > 0) do
      Begin

         // Decodifica o Pacote ou o restante dele
         Try
            ZeraRecord;
            TipoPacket := Decode;
         Except
            TipoPacket := 0;
            erro := True;
            Inc(ContErros);
            SqlExec :=
               'insert into acp245.acp_recebidos (id, data_rec, tipo, duplica                                  do, ip_origem, pacote) values (';
            SqlExec := SqlExec + QuotedStr(Processar.FieldByName('ID')
               .AsString) + ',';
            SqlExec := SqlExec + 'now(),';
            SqlExec := SqlExec + '0,';
            SqlExec := SqlExec + InttoStr(Processar.FieldByName('Duplicado')
               .AsInteger) + ',';
            SqlExec := SqlExec + 'Select INET_ATON(' +
               QuotedStr(Processar.FieldByName('IP').AsString) + '),';
            SqlExec := SqlExec + QuotedStr(inttoStr(PortaLocal) + ' : ' + PacketStr) + ');';
            SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
            Continue;
         End;

         { if (TipoPacket <> 99) and (AcpHeader.Ok = True) then
           Begin
           SqlExec := 'insert into acp245.acp_recebidos values (';
           SqlExec := SqlExec +  QuotedStr(Copy(Trim(Processar.FieldByName('ID').AsString) + AcpVehicle.SIMCard_ID,1,20)) + ',';
           SqlExec := SqlExec +  'now(),' ;
           SqlExec := SqlExec +  InttoStr(TipoPacket) + ',';
           SqlExec := SqlExec +  QuotedStr(PacketStr) + ');';
           SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
           End
           Else }
         if (Not AcpHeader.Ok) or
            (Processar.FieldByName('Duplicado').AsInteger = 1) or (Corrigido > 0)
         then
         Begin
            SqlExec :=
               'insert into acp245.acp_recebidos (id, data_rec, tipo, duplicado, ip_origem, pacote) values (';
            SqlExec := SqlExec +
               QuotedStr(Copy(Trim(Processar.FieldByName('ID').AsString) +
               AcpVehicle.SIMCard_ID, 1, 20)) + ',';
            SqlExec := SqlExec + ' now(),';
            SqlExec := SqlExec + '0,';
            if Processar.FieldByName('Duplicado').AsInteger = 1 then
               SqlExec := SqlExec + InttoStr(Processar.FieldByName('Duplicado')
                  .AsInteger) + ','
            Else
               SqlExec := SqlExec + InttoStr(Corrigido) + ',';

            SqlExec := SqlExec + 'INET_ATON(' +
               QuotedStr(Processar.FieldByName('IP').AsString) + '),';
            SqlExec := SqlExec + QuotedStr(PacketStr) + ');';
            SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
         End;

         if (TipoPacket = 99) or
            (Processar.FieldByName('Duplicado').AsInteger = 1) then
         Begin
            SetLength(PacketTot, 0);
            Continue
         End
         Else if (Not AcpHeader.Ok) then
         Begin
            SetLength(PacketTot, 0);
            erro := True;
            Inc(ContErros);
            Continue;
         End;

         // Se o ID For Branco - Acabou de Logar
         // Grava os dados do TCU
         if (Not erro) and (Processar.FieldByName('ID').AsString = '') and
            (AcpVehicle.SIMCard_ID <> '') and (AcpVersion.TCU_Manufacturer = 135)
         then
         Begin
            SqlExec := 'Call nexsat.atualiza_acp245_data(';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ',';
            SqlExec := SqlExec + InttoStr(AcpVersion.Car_Manufacturer) + ',';
            SqlExec := SqlExec + InttoStr(AcpVersion.TCU_Manufacturer) + ',';
            SqlExec := SqlExec +
               InttoStr(AcpVersion.Major_Hardware_Release) + ',';
            SqlExec := SqlExec +
               InttoStr(AcpVersion.Major_Software_Release) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.Language) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.VIN) + ',';
            SqlExec := SqlExec + InttoStr(AcpVehicle.TCU_Serial) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.Vehicle_Color) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.Vehicle_Model) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.License_Plate) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.IMEI) + ',';
            SqlExec := SqlExec + InttoStr(AcpVehicle.Vehicle_Model_year) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ',';
            SqlExec := SqlExec + QuotedStr(AcpVehicle.Auth_Key) + ');';

            SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

         End;

         // Salva o Id Decodificado
         if (Not erro) and (TipoPacket > 0) and (AcpVehicle.SIMCard_ID <> '')
            and (((now - FileDate) * 60 * 24) <= 5) and (now > ServerStartUp)
            and (AcpVersion.TCU_Manufacturer = 135) then
            Try
               Processado.Insert;
               Processado.FieldByName('ID').AsString := AcpVehicle.SIMCard_ID;
               Processado.FieldByName('IP').AsString :=
                  Processar.FieldByName('IP').AsString;
               Processado.FieldByName('Porta').AsString :=
                  Processar.FieldByName('Porta').AsString;
               Processado.FieldByName('Tcp_Client').AsString :=
                  Processar.FieldByName('Tcp_Client').AsString;
               if Length(Resposta) > 0 then
               Begin
                  StreamRes := TMemoryStream.Create;
                  ByteArrayToStream(Resposta, StreamRes);
                  blobR := Processado.FieldByName('Resposta') as TBlobField;
                  Try
                     try
                        blobR.LoadFromStream(StreamRes);
                     finally
                        StreamRes.Free;
                     end;
                  Except
                     erro := True;
                     Inc(ContErros);
                     SalvaLog(Arq_Log,
                        'Erro ao Salvar o TBlobField-Resposta: ');
                  End;
               End;
               Processado.Post;

            Except
               SalvaLog(Arq_Log, 'Erro ao Inserir Resposta: ');
               erro := True;
               Inc(ContErros);
               Continue;
            End;

         If (Not erro) and (TipoPacket in [10, 11]) and
            (AcpVehicle.SIMCard_ID <> '') and
            (AcpVersion.TCU_Manufacturer = 135) and (AcpHeader.Ok) then

            Try
               // Trata a hora antes...
               if AcpTimeStamp.Msg_DataHora < now - 365 Then
                  AcpTimeStamp.Msg_DataHora := now;

               SqlExec := SqlTracking;
               SqlExec := SqlExec + 'Values(';
               SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
               SqlExec := SqlExec + 'DATE_SUB( ' +
                  QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',
                  AcpTimeStamp.Msg_DataHora)) +
                  ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
               SqlExec := SqlExec +
                  Troca(FormatFloat('###0.######',
                  AcpGPS_Current_Coding.Latitude)) + ', ';
               SqlExec := SqlExec +
                  Troca(FormatFloat('###0.######',
                  AcpGPS_Current_Coding.Longitude)) + ', ';
               SqlExec := SqlExec + InttoStr(PortaLocal) + ', ';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('IP')
                  .AsString) + ', ';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('Porta')
                  .AsString) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpGPS_Current_Coding.Velocity) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpGPS_Current_Coding.Angulo) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpGPS_Current.Number_Satellites) + ', ';
               SqlExec := SqlExec + InttoStr(AcpGPS_Current.Atualizado) + ', ';
               SqlExec := SqlExec + InttoStr(AcpBreakDown.Chave) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpBreakDown.Bateria_Violada) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpBreakDown.Bateria_Religada) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpBreakDown.Breakdown_Flag1) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpBreakDown.Breakdown_Flag2) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpBreakDown.Breakdown_Flag3) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpBreakDown.Breakdown_Flag4) + ', ';
               SqlExec := SqlExec + '27';
               SqlExec := SqlExec + ');';
               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

               if (AcpBreakDown.Breakdown_Flag1 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpBreakDown.Breakdown_Flag1);
                  for Contador := 1 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpTimeStamp.Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_1') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if (AcpBreakDown.Breakdown_Flag2 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpBreakDown.Breakdown_Flag2);
                  for Contador := 1 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpTimeStamp.Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_2') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if (AcpBreakDown.Breakdown_Flag3 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpBreakDown.Breakdown_Flag3);
                  for Contador := 1 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpTimeStamp.Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_3') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if (AcpBreakDown.Breakdown_Flag4 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpBreakDown.Breakdown_Flag4);
                  for Contador := 1 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpTimeStamp.Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_4') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if AcpBreakDown.Bateria_Religada = 1 then
               Begin
                  SqlExec := 'call recebe_parametros_cpr(';
                  SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                  SqlExec := SqlExec + QuotedStr('BATERIA') + ',' +
                     QuotedStr('RELIGADA') + '); ';
                  SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
               End;
               if AcpBreakDown.Bateria_Violada = 1 then
               Begin
                  SqlExec := 'call recebe_parametros_cpr(';
                  SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                  SqlExec := SqlExec + QuotedStr('BATERIA') + ',' +
                     QuotedStr('VIOLADA') + '); ';
                  SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
               End;
            Except
               on E: Exception do
               begin
                  SalvaLog(Arq_Log, 'Erro ao Gerar Insert (MySql): ' +
                     E.Message);
                  erro := True;
                  Continue;
               end;

            End
         Else if (Not erro) and (TipoPacket in [2]) and
            (AcpVehicle.SIMCard_ID <> '') and (AcpVersion.TCU_Manufacturer = 135)
         then
            Try
               //
               if Length(AcpDataError) = 0 then
               Begin
                  // So tem 1 error
                  SqlExec := 'call recebe_parametros_cpr(';
                  SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                  SqlExec := SqlExec + QuotedStr('PARAMETER_ERROR') + ',';
                  SqlExec := SqlExec + QuotedStr(InttoStr(AcpError.Error_Code));
                  SqlExec := SqlExec + '); ';

                  SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

               End
               Else
               Begin
                  SalvaLog(Arq_Log, 'Tamanho do vetor AcpDataError ' +
                     InttoStr(Length(AcpDataError)) + ' ! ID:' +
                     AcpVehicle.SIMCard_ID + ' - ' + PacketStr);
                  // Multiplos erros
                  for Contador := 0 to Length(AcpDataError) - 1 do
                  Begin
                     SqlExec := 'call recebe_parametros_cpr(';
                     SqlExec := SqlExec +
                        QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
                     SqlExec := SqlExec +
                        QuotedStr('PARAMETER_' +
                        IntToHex(AcpDataError[Contador].Data_Type_MSB, 2) +
                        IntToHex(AcpDataError[Contador].Data_Type_LSB,
                        2)) + ',';
                     SqlExec := SqlExec +
                        QuotedStr(AcpDataError[Contador].Configuration_Data);
                     SqlExec := SqlExec + '); ';

                     SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                  End;
               End;

               SqlExec :=
                  'Update nexsat.comandos_envio Set Status = 3, dt_envio = now()'
                  + ' Where id = ' + QuotedStr(AcpVehicle.SIMCard_ID) +
                  ' and Sequencia = ' + Processar.FieldByName('MsgSequencia')
                  .AsString + ' and Status = 1;';

               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

            Except
               on E: Exception do
               begin
                  SalvaLog(Arq_Log, 'Erro ao Criar Insert (MySql-Packet 2): ' +
                     E.Message + SqlExec);
                  Inc(ContErros);
                  Processar.Next;
                  Continue;
               end;

            End
         Else if (Not erro) and (TipoPacket in [6]) and
            (AcpVehicle.SIMCard_ID <> '') and
            (AcpVersion.TCU_Manufacturer = 135) and (AcpHeader.Ok) then
            Try

               SqlExec := 'call recebe_parametros_cpr(';
               SqlExec := SqlExec + QuotedStr(AcpVehicle.SIMCard_ID) + ', ';
               SqlExec := SqlExec +
                  QuotedStr('CONTROL_ENTITY_' +
                  InttoStr(AcpControl_Function.Entity_ID)) + ',';
               Case AcpFunction_Command.Command_or_Status of
                  0:
                     SqlExec := SqlExec + QuotedStr('Permitted');
                  1:
                     SqlExec := SqlExec + QuotedStr('Rejected');
                  2:
                     SqlExec := SqlExec + QuotedStr('Enabled (Started)');
                  3:
                     SqlExec := SqlExec + QuotedStr('Disable (Stop)');
                  4:
                     SqlExec := SqlExec + QuotedStr('Completed');
               Else
                  SqlExec := SqlExec + QuotedStr('UnKnow');
               End;
               SqlExec := SqlExec + '); ';

               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

               SqlExec :=
                  'Update nexsat.comandos_envio Set Status = 3, dt_envio = now()'
                  + ' Where id = ' + QuotedStr(AcpVehicle.SIMCard_ID) +
                  ' and Sequencia = ' + Processar.FieldByName('MsgSequencia')
                  .AsString + ' and Status = 1;';

               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

            Except
               on E: Exception do
               begin
                  SalvaLog(Arq_Log, 'Erro ao Criar Insert (MySql-Packet 6): ' +
                     E.Message + SqlExec);
                  Inc(ContErros);
                  Processar.Next;
                  Continue;
               end;

            End
         Else
         Begin
            if (Debug In [2, 5, 9]) or (AcpVehicle.SIMCard_ID = Debug_ID) then
            Begin
               if not erro then
                  SalvaLog(Arq_Log, 'Não Salvou o Pacote: ' +
                     InttoStr(TipoPacket) + ':' + AcpVehicle.SIMCard_ID)
               Else
                  SalvaLog(Arq_Log, 'Pacote Com erro ! Não Salvou o Pacote: ' +
                     InttoStr(TipoPacket) + ':' + AcpVehicle.SIMCard_ID);
            End;

         End;
      End; // Final do Decode

      if erro then
      Begin
         Inc(ContErros);
         Processar.Next;
      End
      Else
      Begin
//         Inc(ContTrack);
         Processar.Delete;
      End;

   End;

   tFinal := now;

   if (Debug In [2, 5, 9]) or (AcpVehicle.SIMCard_ID = Debug_ID) then
      SalvaLog(Arq_Log, 'Tempo execução Decode: ' + FormatDateTime('ss:zzz',
         tFinal - tInicio) + ' Segundos');

   Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_inbox);
   Arq_Err := DirErros + '\' + ExtractFileName(Arq_inbox);
   Arq_Sql := DirSql + '\' + ExtractFileName(Arq_inbox);

   tInicio := now;
//   SqlPendente := SqlPendente + GeraSqlStatus(PortaLocal, ContTrack, ContTrack, ContErros, -1);

   SalvaArquivo(Arq_Sql, SqlPendente);

   {

     {

     AtualizaStatus(PortaLocal, ContTrack, ContTrack, ContErros, -1, Arq_Log, QryStatus) ;
     If not ExecutarBatch(SqlPendente, Arq_Log, QryBatch) Then
     Begin
     SalvaLog(Arq_Log,'Erro ao executar sql batch: ' + Arq_Sql );
     SalvaArquivo( Arq_Sql, SqlPendente);
     End;
   }

   tFinal := now;

   if (Debug In [2, 5, 9]) or (AcpVehicle.SIMCard_ID = Debug_ID) then
      SalvaLog(Arq_Log, 'Tempo execução Sql batch: ' + Arq_inbox + ' - ' +
         FormatDateTime('ss:zzz', tFinal - tInicio) + ' Segundos');

   Try
      Processado.SaveToFile(Arq_Proce);
      Processado.Close;
   Except
      SalvaLog(Arq_Log, 'Erro ao Salvar arquivo processado: ' + Arq_Proce);
   End;

   Try
      If (ContErros = 0) Then
      Begin
         Processar.Close;
         deletefile(Arq_inbox);
      End
      Else
      Begin
         Processar.SaveToFile(Arq_Err);
         Processar.Close;
         deletefile(Arq_inbox);
      End;
   Except
      SalvaLog(Arq_Log, 'Erro ao Deletar recebidos: ' + Arq_inbox);
   End;

   Sleep(50);

End;

Function Gravacao_Quanta_Acp.Decode: SmallInt;
Var
   Posicao: SmallInt;
   StrBits: String;
   Contador: Word;
   Resto: Word;
   Processado: Word;

Begin

   Try
      Corrigido := 0;
      Posicao := 0;
      SetLength(Resposta, 0);
      if Length(PacketTot) < 3 then
      Begin
         SetLength(PacketTot, 0);
         Result := 0;
         Exit;
      End;

      // Header do Pacote
      // le 3 Bytes para saber se exist o 4 (Opcional)
      StrBits := CharToStrBin(PacketTot, Posicao, 3);
      AcpHeader.Length := 3;

      AcpHeader.reserved1 := StrtoIntDef(StrBits[1],0);
      AcpHeader.private_Flag1 := StrtoIntDef(StrBits[2],0);
      AcpHeader.application_id := BintoInt(Copy(StrBits, 3, 6));

      AcpHeader.reserved2 := StrtoIntDef(StrBits[9],0);
      AcpHeader.private_Flag2 := StrtoIntDef(StrBits[10],0);
      AcpHeader.test_Flag := StrtoIntDef(StrBits[11],0);
      AcpHeader.Message_type := BintoInt(Copy(StrBits, 12, 5));
      AcpHeader.version_Flag := StrtoIntDef(StrBits[17],0);
      AcpHeader.application_version := BintoInt(Copy(StrBits, 18, 3));
      AcpHeader.Message_control_Flag0 := StrtoIntDef(StrBits[21],0);
      AcpHeader.Message_control_Flag1 := StrtoIntDef(StrBits[22],0);
      AcpHeader.Message_control_Flag2 := StrtoIntDef(StrBits[23],0);
      AcpHeader.Message_control_Flag3 := StrtoIntDef(StrBits[24],0);

      // Se o version Flag =1 tem +1 byte no header
      if AcpHeader.version_Flag = 1 then
      Begin
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         AcpHeader.Length := AcpHeader.Length + 1;
         AcpHeader.more_Flag := StrtoInt(StrBits[1]);
         AcpHeader.Message_priority := BintoInt(Copy(StrBits, 7, 2));
      End;

      if AcpHeader.Message_control_Flag2 = 0 then
      // 0 = The message Length field is 8 bits
      Begin
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         AcpHeader.Length := AcpHeader.Length + 1;
         AcpHeader.Message_Length := BintoInt(Copy(StrBits, 1, 8));
      End
      Else if AcpHeader.Message_control_Flag2 = 1 then
      // 1=The message Length field is 16 bits
      Begin
         StrBits := CharToStrBin(PacketTot, Posicao, 2);
         AcpHeader.Length := AcpHeader.Length + 2;
         AcpHeader.Message_Length := BintoInt(Copy(StrBits, 1, 16));
      End;

      AcpHeader.Ok := True;

      Result := AcpHeader.application_id;

      Processado := AcpHeader.Message_Length;
      if Processado > Length(PacketTot) then
         Processado := Length(PacketTot);

      // Tipo Mensagem = 0
      if (AcpHeader.Message_type = 0) then
      Begin
         Result := 0;
         SetLength(PacketTot, 0);
         Exit;
      End
      // Tamanho do Header maior que os dados passsados
      Else if (AcpHeader.Message_Length > Length(PacketTot)) then
      Begin
         Result := 0;
         SetLength(PacketTot, 0);
         Exit;
      End
      // Tipo application_id = 0
      Else if Not(AcpHeader.application_id in [2, 6, 10, 11]) then
      Begin
         Result := 0;
         SetLength(PacketTot, 0);
         Exit;
      End
      // Keep Alive
      Else if (AcpHeader.application_id = 11) and (AcpHeader.Message_type = 4)
      then
      Begin

         If (AcpHeader.Message_control_Flag3 = 1) Then
         Begin
            SetLength(Resposta, 4);
            // 1 Byte Application ID
            Resposta[0] :=
               BintoInt('0' + Copy(IntToStrBin(AcpHeader.private_Flag1), 8, 1) +
               Copy(IntToStrBin(AcpHeader.application_id), 3, 6));
            // 2 Byte MessageType = 2 = Theft Alarm Reply
            Resposta[1] :=
               BintoInt('0' + Copy(IntToStrBin(AcpHeader.private_Flag2), 8, 1) +
               Copy(IntToStrBin(AcpHeader.test_Flag), 8, 1) +
               Copy(IntToStrBin(5), 5, 4));
            // 3 Byte Application Version  + Message Control Flag
            Resposta[2] := BintoInt(Copy(IntToStrBin(AcpHeader.version_Flag), 8,
               1) + Copy(IntToStrBin(AcpHeader.application_version), 6, 3)
               + '0000');
            // 4 Byte Message length
            Resposta[3] := 4;
         End;
         Result := 99;
         Exit;
      End;

      SetLength(PacketRec, Processado);

      for Contador := 0 to Processado - 1 do
         PacketRec[Contador] := PacketTot[Contador];

      // 0-67 68-102
      Resto := Length(PacketTot) - AcpHeader.Message_Length;

      for Contador := Processado to Processado + Resto - 1 do
         PacketTot[Contador - Processado] := PacketTot[Contador];

      SetLength(PacketTot, Resto);

      // APP ID = 2 & Message Type = 3
      if (AcpHeader.application_id = 2) and (AcpHeader.Message_type = 3) then
      Begin
         Posicao := Posicao + Decode_App02_03(Posicao);
      End

      // APP ID = 2 & Message Type = 9
      Else if (AcpHeader.application_id = 2) and (AcpHeader.Message_type = 9)
      then
      Begin
         Posicao := Posicao + Decode_App02_09(Posicao);
      End
      // APP ID = 6
      Else if AcpHeader.application_id = 6 then
      Begin
         Posicao := Posicao + Decode_App06(Posicao);
      End
      // APP ID = 10
      Else if (AcpHeader.application_id = 10) then
      Begin

         Posicao := Posicao + Decode_App10(Posicao);
         if (AcpHeader.Message_control_Flag3 = 1) then
         Begin
            SetLength(Resposta, 13);
            // 1 Byte Application ID
            Resposta[0] :=
               BintoInt('0' + Copy(IntToStrBin(AcpHeader.private_Flag1), 8, 1) +
               Copy(IntToStrBin(AcpHeader.application_id), 3, 6));
            // 2 Byte MessageType = 3 = Theft Alarm Reply
            Resposta[1] :=
               BintoInt('0' + Copy(IntToStrBin(AcpHeader.private_Flag2), 8, 1) +
               Copy(IntToStrBin(AcpHeader.test_Flag), 8, 1) +
               Copy(IntToStrBin(3), 4, 5));
            // 3 Byte Application Version  + Message Control Flag
            Resposta[2] := BintoInt(Copy(IntToStrBin(AcpHeader.version_Flag), 8,
               1) + Copy(IntToStrBin(AcpHeader.application_version), 6, 3)
               + '0000');
            // 4 Byte Message length
            Resposta[3] := 13;
            // 5 Byte Version Element - Header (4 = Length of Version Element)
            Resposta[4] := 4;
            // 6 Byte Version Element - Car Manufacturer ID
            Resposta[5] := AcpVersion.Car_Manufacturer;
            // 7 Byte Version Element - Car Manufacturer ID
            Resposta[6] := AcpVersion.TCU_Manufacturer;
            // 8 Byte Version Element - Major hardware release
            Resposta[7] := AcpVersion.Major_Hardware_Release;
            // 9 Byte Version Element - Major hardware release
            Resposta[8] := AcpVersion.Major_Software_Release;
            // := 4; // ??????????????
            // 10 Byte Message Fields - Confirmation Definitions + Transmit Units
            Resposta[9] := BintoInt('01010000');
            // BintoInt('11010000'); ????????????
            // 11 Byte Message Fields - Ecall ControlFlag2
            Resposta[10] := BintoInt('00010000');
            // 12 Byte Error Element - Header
            Resposta[11] := 1;
            // 13 Byte Error Element - Error Code
            Resposta[12] := 0;
         End;
         // Packet app10

         {
           10:2:33:67:
           4:64:135:1:8:
           84:239:58:129:24:20:18:187:0:0:0:245:255:189:232:250:239:230:132:2:227:255:235:6:0:0:0:0:0:18:144:32:4:0:0:12:186:138:137:85:2:128:0:1:84:116:148:80:8:128:128:0:1:3:128:192:65:0:
         }
      End
      // APP ID = 11
      Else if (AcpHeader.application_id = 11) then
      Begin

         Posicao := Posicao + Decode_App11(Posicao);

         if (AcpHeader.Message_control_Flag3 = 1) then
         Begin
            SetLength(Resposta, 13);
            // 1 Byte Application ID
            Resposta[0] :=
               BintoInt('0' + Copy(IntToStrBin(AcpHeader.private_Flag1), 8, 1) +
               Copy(IntToStrBin(AcpHeader.application_id), 3, 6));
            // 2 Byte MessageType = 2 = Theft Alarm Reply
            Resposta[1] :=
               BintoInt('0' + Copy(IntToStrBin(AcpHeader.private_Flag2), 8, 1) +
               Copy(IntToStrBin(AcpHeader.test_Flag), 8, 1) +
               Copy(IntToStrBin(2), 4, 5));
            // 3 Byte Application Version  + Message Control Flag
            Resposta[2] := BintoInt(Copy(IntToStrBin(AcpHeader.version_Flag), 8,
               1) + Copy(IntToStrBin(AcpHeader.application_version), 6, 3)
               + '0000');
            // 4 Byte Message length
            Resposta[3] := 13;
            // 5 Byte Version Element - Header (4 = Length of Version Element)
            Resposta[4] := 4;
            // 6 Byte Version Element - Car Manufacturer ID
            Resposta[5] := AcpVersion.Car_Manufacturer;
            // 7 Byte Version Element - Car Manufacturer ID
            Resposta[6] := AcpVersion.TCU_Manufacturer;
            // 8 Byte Version Element - Major hardware release
            Resposta[7] := AcpVersion.Major_Hardware_Release;
            // 9 Byte Version Element - Major hardware release
            Resposta[8] := AcpVersion.Major_Software_Release;
            // := 4; // ??????????????
            // 10 Byte Message Fields - Confirmation Definitions + Transmit Units
            Resposta[9] := BintoInt('01010000');
            // BintoInt('11010000'); ????????????
            // 11 Byte Message Fields - Ecall ControlFlag2
            Resposta[10] := BintoInt('00010000');
            // 12 Byte Error Element - Header
            Resposta[11] := 1;
            // 13 Byte Error Element - Error Code
            Resposta[12] := 0;
         End;
         // Packet app11
         {
           11:1:33:69:
           4:64:135:1:8:
           84:237:93:234:
           24:20:18:187:0:0:0:245:255:189:232:250:239:228:84:3:25:255:244:6:0:0:0:0:0:
           18:144:32:4:0:0:12:186:138:137:85:2:128:0:1:84:116:148:80:
           10:128:128:128:64:1:4:128:160:193:64:
           0:
         }

         // Resposta app11
         {
           11:2:32:13:4:64:135:1:4:208:16:1:0:
           11:2:32:13:4:64:135:1:8:80:16:1:0:
           11:2:32:13:4:64:135:1:8:80:16:1:0:

         }

      End
      Else
      Begin
         SalvaLog(Arq_Log, 'Não decodificou (1): ' + PacketStr);
         SetLength(PacketTot, 0);
         Result := 0;
         AcpHeader.Ok := False;
      End;

   Except

      Begin
         SalvaLog(Arq_Log, 'Não decodificou (2): ' + PacketStr);
         SetLength(PacketTot, 0);
         Result := 0;
         AcpHeader.Ok := False;
      End;
   End;

End;

// Single Error Element
Function Gravacao_Quanta_Acp.Decode_App02_03(Var pInicial: SmallInt): SmallInt;
Var
   Posicao: SmallInt;

Begin
   {
     Recebido:
     02032022     Application Header
     0440870109   Version Element
     00           Reserved
     000280       Message Fields
     0118         Error Element
     12902004000056468A89550280000165332080  Vehicle Descriptor
   }
   Try
      Posicao := pInicial;

      // Version
      Posicao := Decode_Version(Posicao);

      // Reserved
      Posicao := Decode_Reserved(Posicao);

      // Message Fields
      Posicao := Decode_Message(Posicao);

      // Error Element
      Posicao := Decode_Error(Posicao);

      // Vehicle Descriptor Element
      Posicao := Decode_Vehicle(Posicao);

      Result := Posicao;
   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App02_03): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpHeader.Ok := False;
   End;
End;

// Multiple Error Element
Function Gravacao_Quanta_Acp.Decode_App02_09(Var pInicial: SmallInt): SmallInt;
Var
   Posicao: SmallInt;
Begin
   Try
      Posicao := pInicial;

      // Version
      Posicao := Decode_Version(Posicao);

      // Message Fields
      Posicao := Decode_Message(Posicao);

      // Error Element
      Posicao := Decode_TCU_Data_Error(Posicao);

      // Vehicle Descriptor Element
      Posicao := Decode_Vehicle(Posicao);

      {
        --Header
        02 -- Application ID
        09 -- Message Type
        20 -- Application Version - Message Control Flag
        25 -- Message Length

        --Version Element
        04 -- Version Element  - Length
        40 -- Car Manufacturer ID
        87 -- TCU Manufacturer ID
        01 -- Major hardware release
        09 -- Major software release

        --Message Fields
        00 -- Message Field
        C2 -- ApplFlag1 + ControlFlag1
        80 -- Status Flag1 + TCU Response Flag

        --TCU Data Error Element
        05 -- Decode_TCU_Data_Error - Length
        00 -- Data Type MSB
        11 -- Data Type LSB
        00 -- Length Data Type
        01 -- Configuration Data
        00 -- Error Element

        12 --
        90
        20
        04
        00
        00
        49
        01
        8A
        89
        55
        02
        80
        00
        02
        00
        84
        27
        70
      }
      Result := Posicao;
   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App02_09): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_App06(Var pInicial: SmallInt): SmallInt;
Var
   Posicao: SmallInt;
Begin
   {
     6:3:32:36:4:64:135:1:8:3:0:0:0:1:1:1:4:18:144:32:4:0:0:12:186:138:137:85:2:128:0:1:84:116:148:80:
     6:3:32:36:      //Header
     4:64:135:1:8:   //Version
     3:128:0:255:    //Control Function
     1:3:            //Function Command
     1:0:            //Error Element
     18:144:32:4:0:0:12:186:138:137:85:2:128:0:1:84:116:148:80:    //Vehicle Descriptor Element

   }
   Try
      Posicao := pInicial;

      // Version
      Posicao := Decode_Version(Posicao);

      // Control Function
      Posicao := Decode_Control_Function(Posicao);

      // Function Command
      Posicao := Decode_Function_Command(Posicao);

      // Error Element
      Posicao := Decode_Error(Posicao);

      // Vehicle
      Posicao := Decode_Vehicle(Posicao);

      Result := Posicao;
   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App06): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_App10(Var pInicial: SmallInt): SmallInt;
Var
   Posicao: SmallInt;
Begin
   {
     -- Header
     10:2:33:67:
     -- Version
     4:64:135:1:8:
     -- TimeStamp
     85:41:49:30:
     --Location
     24:20:18:128:39:0:0:245:253:44:184:250:235:77:144:3: 7:3:245:6:0:144:0:0:0:
     --Vehicle
     18:144:32:4:0:0:56:203:138:137:85:2:128:0:1:101:37: 20:136:
     --BreakDown
     8:128:128:0:1:3:128:192:65:
     --Error
     0:
   }
   Try
      Posicao := pInicial;
      // Version
      Posicao := Decode_Version(Posicao);

      // TimeStamp Element 4 Bytes
      Posicao := Decode_TimeStamp(Posicao);

      // TimeStamp Element 4 Bytes
      Posicao := Decode_Location(Posicao);

      // Vehicle
      Posicao := Decode_Vehicle(Posicao);

      // BreakDown
      Posicao := Decode_BreakDown(Posicao, 10);

      Result := Posicao;

   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App10): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_App11(Var pInicial: SmallInt): SmallInt;
Var
   Posicao: SmallInt;
Begin
   Try
      Posicao := pInicial;
      // Version Element 5 Bytes
      Posicao := Decode_Version(Posicao);

      // TimeStamp Element 4 Bytes
      Posicao := Decode_TimeStamp(Posicao);

      // TimeStamp Element 24 Bytes (media)
      Posicao := Decode_Location(Posicao);

      // Vehicle Element 18 bytes (media)
      Posicao := Decode_Vehicle(Posicao);

      // BreakDown
      Posicao := Decode_BreakDown(Posicao, 11);

      Result := Posicao;
   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App11): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_Version(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
   BytesRest: SmallInt;

Begin
Result := pInicial;
   Try

      PosInicio := pInicial;
      BytesRest := Length(PacketRec) - pInicial;

      // Header do Version
      StrBits := CharToStrBin(PacketRec, pInicial, 1);
      AcpVersion.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpVersion.more_Flag := StrtoInt(StrBits[3]);
      AcpVersion.Length := BintoInt(Copy(StrBits, 4, 5));

      if AcpVersion.Length > 0 then
      Begin
         // Version dados
         StrBits := CharToStrBin(PacketRec, pInicial, AcpVersion.Length);
         AcpVersion.Car_Manufacturer := BintoInt(Copy(StrBits, 1, 8));
         AcpVersion.TCU_Manufacturer := BintoInt(Copy(StrBits, 9, 8));
         AcpVersion.Major_Hardware_Release := BintoInt(Copy(StrBits, 17, 8));
         AcpVersion.Major_Software_Release := BintoInt(Copy(StrBits, 25, 8));
      End;

      if (AcpVersion.Car_Manufacturer = 0) or (AcpVersion.TCU_Manufacturer = 0)
         or (AcpVersion.Major_Hardware_Release = 0) or
         (AcpVersion.Major_Software_Release = 0) then
         Result := 0
      Else
         Result := pInicial;

      if (pInicial - PosInicio <> AcpVersion.Length + 1) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Version - Bytes processados / Deveria Processar: ' +
            InttoStr(pInicial - PosInicio) + '/' +
            InttoStr(AcpVersion.Length + 1));
         Corrigido := 2;
      End;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Version: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_TimeStamp(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
Begin
Result := pInicial;
   Try

      PosInicio := pInicial;

      // Header de TimeStamp Element 4 Bytes
      StrBits := CharToStrBin(PacketRec, pInicial, 4);
      AcpTimeStamp.Length := 4;
      Try
         AcpTimeStamp.Msg_DataHora :=
            EncodeDateTime(1990 + BintoInt(Copy(StrBits, 1, 6)), // Ano
            BintoInt(Copy(StrBits, 7, 4)), // Mes
            BintoInt(Copy(StrBits, 11, 5)), // Dia
            BintoInt(Copy(StrBits, 16, 5)), // Hora
            BintoInt(Copy(StrBits, 21, 6)), // Minuto
            BintoInt(Copy(StrBits, 27, 6)), // Segundo
            0); // Milisegundos

      Except

      End;

      Result := pInicial;
      if (pInicial - PosInicio <> AcpTimeStamp.Length) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_TimeStamp - Bytes processados / Deveria Processar: ' +
            InttoStr(pInicial - PosInicio) + '/' +
            InttoStr(AcpTimeStamp.Length));
         Corrigido := 3;
      End;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_TimeStamp: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;

End;

Function Gravacao_Quanta_Acp.Decode_Location(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
Begin
Result := pInicial;
   Try

      PosInicio := pInicial;

      // Header de Location element
      StrBits := CharToStrBin(PacketRec, pInicial, 1);
      AcpLocation.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpLocation.more_Flag := StrtoInt(StrBits[3]);
      AcpLocation.Length := BintoInt(Copy(StrBits, 4, 5));

      if AcpLocation.more_Flag = 1 then
      Begin
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpLocation.Length := BintoInt(Copy(StrBits, 4, 5));
      End;

      if (AcpLocation.Length > 0) Then
      Begin

         // GPSRawData Current Element
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpGPS_Current.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpGPS_Current.more_Flag := StrtoInt(StrBits[3]);
         AcpGPS_Current.Length := BintoInt(Copy(StrBits, 4, 5));

         if AcpGPS_Current.Length > 0 then
         Begin

            // GPSRawData Area Location Coding
            if (AcpGPS_Current.Length > 0) then
            Begin
               StrBits := CharToStrBin(PacketRec, pInicial, 1);
               AcpGPS_Current_Coding.IEIdentifier :=
                  BintoInt(Copy(StrBits, 1, 2));
               AcpGPS_Current_Coding.more_Flag := StrtoInt(StrBits[3]);
               AcpGPS_Current_Coding.Length := BintoInt(Copy(StrBits, 4, 5));
            End;

            if (AcpGPS_Current_Coding.Length > 0) then
            Begin

               StrBits := CharToStrBin(PacketRec, pInicial,
                  AcpGPS_Current_Coding.Length);

               // 1 byte - 1
               AcpGPS_Current_Coding.Location_Flag1 :=
                  BintoInt(Copy(StrBits, 2, 7));

               // 1 byte - 8
               AcpGPS_Current_Coding.Location_Flag2 :=
                  BintoInt(Copy(StrBits, 9, 4));
               AcpGPS_Current_Coding.Angulo :=
                  BintoInt(Copy(StrBits, 14, 3)) * 45;

               // 1 byte - 16
               AcpGPS_Current_Coding.areatype := BintoInt(Copy(StrBits, 17, 3));
               AcpGPS_Current_Coding.locationtypecoding :=
                  BintoInt(Copy(StrBits, 20, 3));

               // 1 byte  -24
               AcpGPS_Current_Coding.time_difference :=
                  BintoInt(Copy(StrBits, 26, 7));

               // 4 bytes -32
               AcpGPS_Current_Coding.Longitude :=
                  CompTwoToLatLong(Copy(StrBits, 33, 32));

               // 4 bytes -64
               AcpGPS_Current_Coding.Latitude :=
                  CompTwoToLatLong(Copy(StrBits, 65, 32));

               // 2 bytes -96
               AcpGPS_Current_Coding.altitude :=
                  BintoInt(Copy(StrBits, 97, 16));

               // 1 byte  -112
               AcpGPS_Current_Coding.Position_estimate_value :=
                  BintoInt(Copy(StrBits, 113, 7));
               AcpGPS_Current_Coding.Position_estimate_type :=
                  BintoInt(Copy(StrBits, 120, 1));

               // 1 byte  -120
               AcpGPS_Current_Coding.heading_estimate_Type :=
                  BintoInt(Copy(StrBits, 121, 3));
               AcpGPS_Current_Coding.heading_estimate_value :=
                  BintoInt(Copy(StrBits, 124, 5));

               // 1 byte  -128
               AcpGPS_Current_Coding.distance_Flag :=
                  BintoInt(Copy(StrBits, 133, 2));
               AcpGPS_Current_Coding.time_Flag :=
                  BintoInt(Copy(StrBits, 135, 2));

               // 1 byte  -136
               AcpGPS_Current_Coding.Velocity :=
                  BintoInt(Copy(StrBits, 137, 8));

               if (BintoInt(Copy(StrBits, 5, 1)) = 1) then
                  AcpGPS_Current.Atualizado := 0
               Else
                  AcpGPS_Current.Atualizado := 1;

            End;

            // GPSRawData Current Element - Number Satelites
            StrBits := CharToStrBin(PacketRec, pInicial, 1);
            AcpGPS_Current.Number_Satellites := BintoInt(Copy(StrBits, 1, 4));

            { if  AcpGPS_Current.Number_Satellites > 0 then
              Begin
              StrBits :=  CharToStrBin(PacketRec,pInicial,AcpGPS_Current.Number_Satellites );
              End;
            }
         End;

         // GPSRawData Prior Element
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpGPS_Prior.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpGPS_Prior.more_Flag := StrtoInt(StrBits[3]);
         AcpGPS_Prior.Length := BintoInt(Copy(StrBits, 4, 5));

         if AcpGPS_Prior.Length > 0 then
         Begin

            // GPSRawData Area Location Coding
            if (AcpGPS_Prior.Length > 0) then
            Begin
               StrBits := CharToStrBin(PacketRec, pInicial, 1);
               AcpGPS_Prior_Coding.IEIdentifier :=
                  BintoInt(Copy(StrBits, 1, 2));
               AcpGPS_Prior_Coding.more_Flag := StrtoInt(StrBits[3]);
               AcpGPS_Prior_Coding.Length := BintoInt(Copy(StrBits, 4, 5));
            End;

            if (AcpGPS_Prior_Coding.Length > 0) then
            Begin
               StrBits := CharToStrBin(PacketRec, pInicial,
                  AcpGPS_Current_Coding.Length);
               AcpGPS_Prior_Coding.Location_Flag1 :=
                  BintoInt(Copy(StrBits, 2, 7));
               AcpGPS_Prior_Coding.Location_Flag2 :=
                  BintoInt(Copy(StrBits, 9, 4));
               AcpGPS_Prior_Coding.Angulo := BintoInt(Copy(StrBits, 14, 3));
               AcpGPS_Prior_Coding.areatype := BintoInt(Copy(StrBits, 17, 3));
               AcpGPS_Prior_Coding.locationtypecoding :=
                  BintoInt(Copy(StrBits, 20, 3));
               AcpGPS_Prior_Coding.time_difference :=
                  BintoInt(Copy(StrBits, 26, 7));
               AcpGPS_Prior_Coding.Longitude :=
                  CompTwoToLatLong(Copy(StrBits, 33, 32));
               AcpGPS_Prior_Coding.Longitude :=
                  CompTwoToLatLong(Copy(StrBits, 65, 32));
               AcpGPS_Prior_Coding.altitude := BintoInt(Copy(StrBits, 97, 16));
               AcpGPS_Prior_Coding.Position_estimate_value :=
                  BintoInt(Copy(StrBits, 113, 7));
               AcpGPS_Prior_Coding.Position_estimate_type :=
                  BintoInt(Copy(StrBits, 120, 1));
               AcpGPS_Prior_Coding.heading_estimate_Type :=
                  BintoInt(Copy(StrBits, 121, 3));
               AcpGPS_Prior_Coding.heading_estimate_value :=
                  BintoInt(Copy(StrBits, 124, 5));
               AcpGPS_Prior_Coding.distance_Flag :=
                  BintoInt(Copy(StrBits, 133, 4));
               AcpGPS_Prior_Coding.time_Flag := BintoInt(Copy(StrBits, 137, 4));
               AcpGPS_Prior_Coding.Velocity := BintoInt(Copy(StrBits, 141, 8));
               AcpGPS_Prior.Atualizado := BintoInt(Copy(StrBits, 5, 1));

            End;
            // GPSRawData Current Element - Number Satelites
            StrBits := CharToStrBin(PacketRec, pInicial, 1);
            AcpGPS_Prior.Number_Satellites := BintoInt(Copy(StrBits, 1, 4));

         End;

         // Current Dead Reckoning Data AcpCDRD_WGS84
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpCDRD_WGS84.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpCDRD_WGS84.more_Flag := StrtoInt(StrBits[3]);
         AcpCDRD_WGS84.Length := BintoInt(Copy(StrBits, 4, 5));

         // Array of Area Location Delta Coding
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpArea_Delta.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpArea_Delta.more_Flag := StrtoInt(StrBits[3]);
         AcpArea_Delta.Length := BintoInt(Copy(StrBits, 4, 5));

      End;

      if (pInicial - PosInicio <> AcpLocation.Length + 1) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Location - Bytes processados / Deveria Processar: ' +
            InttoStr(pInicial - PosInicio) + '/' +
            InttoStr(AcpLocation.Length + 1));
         pInicial := PosInicio + AcpLocation.Length + 1;
         Corrigido := 4;
      End;

      Result := pInicial;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Location: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;

End;

Function Gravacao_Quanta_Acp.Decode_Vehicle(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
   TmpBytes: Word;
   IEIdentifier: byte; // Para os parametros Opcionais
   more_Flag: byte; // Para os parametros Opcionais
   Tamanho: byte; // Para os parametros Opcionais

Begin
   Result := pInicial;
   Try
      { 12 --
        90
        20
        04
        00
        00
        49
        01
        8A
        89
        55
        02
        80
        00
        02
        00
        84
        27
        70
      }
      PosInicio := pInicial;
      // Header do Vehicle
      StrBits := CharToStrBin(PacketRec, pInicial, 1);
      AcpVehicle.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpVehicle.more_Flag := StrtoInt(StrBits[3]);
      AcpVehicle.Length := BintoInt(Copy(StrBits, 4, 5));

      // Tem pelo menos os flags do vehicle
      if AcpVehicle.Length >= 2 Then
      Begin

         StrBits := CharToStrBin(PacketRec, pInicial, 2);
         // Vehicle Flag 1
         AcpVehicle.Flag_Addl_Flag1 := BintoInt(StrBits[1]);
         AcpVehicle.Flag_Language := BintoInt(StrBits[2]);
         AcpVehicle.Flag_VIN := BintoInt(StrBits[3]);
         AcpVehicle.Flag_TCU_Serial := BintoInt(StrBits[4]);
         AcpVehicle.Flag_Vehicle_Color := BintoInt(StrBits[5]);
         AcpVehicle.Flag_Vehicle_Model := BintoInt(StrBits[6]);
         AcpVehicle.Flag_License_Plate := BintoInt(StrBits[7]);
         AcpVehicle.Flag_IMEI := BintoInt(StrBits[8]);
         // Vehicle Flag 2
         AcpVehicle.Flag_Addl_Flag2 := BintoInt(StrBits[9]);
         AcpVehicle.Flag_Vehicle_Model_year := BintoInt(StrBits[10]);
         AcpVehicle.Flag_SIMCard_ID := BintoInt(StrBits[11]);
         AcpVehicle.Flag_Auth_Key := BintoInt(StrBits[12]);

      End;

      // Language
      if AcpVehicle.Flag_Language = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.Language := InttoStr(BintoInt(StrBits));
         End;
      End;

      // Model year
      if AcpVehicle.Flag_Vehicle_Model_year = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.Vehicle_Model_year := BintoInt(StrBits);
         End;
      End;

      // VIN
      if AcpVehicle.Flag_VIN = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            // Mudar: aki é texto
            AcpVehicle.VIN := InttoStr(BintoInt(StrBits));
         End;
      End;

      // TCU serial
      if AcpVehicle.Flag_TCU_Serial = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.TCU_Serial := BintoInt(StrBits);
         End;
      End;

      // License Plate
      if AcpVehicle.Flag_License_Plate = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.License_Plate := InttoStr(BintoInt(StrBits));
         End;
      End;

      // Vehicle Color
      if AcpVehicle.Flag_Vehicle_Color = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.Vehicle_Color := InttoStr(BintoInt(StrBits));
         End;
      End;

      // Vehicle Model
      if AcpVehicle.Flag_Vehicle_Model = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.Vehicle_Model := InttoStr(BintoInt(StrBits));
         End;
      End;

      // IMEI
      if AcpVehicle.Flag_IMEI = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.IMEI := BCDtoString(StrBits);
         End;
      End;

      // SIM Card ID
      if AcpVehicle.Flag_SIMCard_ID = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.SIMCard_ID := Trim(BCDtoString(StrBits));
         End;
      End;

      // Auth. Key
      if AcpVehicle.Flag_Auth_Key = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, Tamanho);
            AcpVehicle.Auth_Key := InttoStr(BintoInt(StrBits));
         End;
      End;

      if (Length(AcpVehicle.SIMCard_ID) <> 20) or (AcpVehicle.SIMCard_ID = '')
         or (Copy(AcpVehicle.SIMCard_ID, 1, 4) <> '8955') then
      Begin
         SalvaLog(Arq_Log, 'ID Invalido: ' + AcpVehicle.SIMCard_ID);
         AcpHeader.Ok := False;
      End;

      Result := pInicial;
      if (pInicial - PosInicio <> AcpVehicle.Length + 1) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Vehicle - Bytes processados / Deveria Processar: ' +
            InttoStr(pInicial - PosInicio) + '/' +
            InttoStr(AcpVehicle.Length + 1));
         Corrigido := 5;
      End;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Vehicle: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;

End;

Function Gravacao_Quanta_Acp.Decode_BreakDown(Var pInicial: SmallInt;
   pTipo_App: Integer): SmallInt;
Var
   StrBits: String;
   // TmpBytes      : Word;
   Contador: Word;
   IEIdentifier: byte; // Para os parametros Opcionais
   more_Flag: byte; // Para os parametros Opcionais
   Length: byte; // Para os parametros Opcionais

Begin
Result := pInicial;
   Try

      PosInicio := pInicial;
      // Header BreakDown
      StrBits := CharToStrBin(PacketRec, pInicial, 1);
      AcpBreakDown.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpBreakDown.more_Flag := StrtoInt(StrBits[3]);
      AcpBreakDown.Length := BintoInt(Copy(StrBits, 4, 5));

      if AcpBreakDown.Length > 1 then
      Begin

         // BreakDown Flag1 - Obrigatorio
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpBreakDown.Breakdown_Flag1 := BintoInt(StrBits);

         if (pTipo_App = 11) and (Debug in [9]) then
            SalvaLog(Arq_Log, 'BreakDown Flag1: ' + StrBits);

         // BreakDown Flag2 - Obrigatorio
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpBreakDown.Breakdown_Flag2 := BintoInt(StrBits);
         if (pTipo_App = 11) and (Debug in [9]) then
            SalvaLog(Arq_Log, 'BreakDown Flag2: ' + StrBits);

         if Copy(StrBits, 2, 1) = '1' then
            AcpBreakDown.Chave := 1
         Else
            AcpBreakDown.Chave := 0;

         // Se more Flag = 1
         if StrBits[1] = '1' then
         Begin
            // BreakDown Flag3
            StrBits := CharToStrBin(PacketRec, pInicial, 1);
            AcpBreakDown.Breakdown_Flag3 := BintoInt(StrBits);
            if (pTipo_App = 11) and (Debug in [9]) then
               SalvaLog(Arq_Log, 'BreakDown Flag3: ' + StrBits);

            if StrBits[4] = '1' then // Main battery is reconnected
               AcpBreakDown.Bateria_Religada := 1;
            if StrBits[5] = '1' then
               AcpBreakDown.Bateria_Violada := 1;

            // More flag = 1 means that there is additional breakdown sources flags defined by TCU suppliers.
            if StrBits[1] = '1' then
            Begin
               StrBits := CharToStrBin(PacketRec, pInicial, 1);
               AcpBreakDown.Breakdown_Flag4 := BintoInt(StrBits);
            End;

         End;

         // BreakDown Sensor
         // When Breakdown sensor bit 7 is set to 1, the format of breakdown data field is the same as described in item 3.9.1 and represents breakdown source status
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpBreakDown.Breakdown_sensor := BintoInt(StrBits);
         AcpBreakDown.Status := BintoInt(StrBits[8]);

         // Header BreakDown Data
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Length := BintoInt(Copy(StrBits, 4, 5));

         // Quando nao for app_id = 11 Alarme Entao os flags estao no Status
         if (AcpBreakDown.Status = 1) and (Length >= 1) then
         Begin

            // BreakDown Flag1
            StrBits := CharToStrBin(PacketRec, pInicial, 1);
            AcpBreakDown.Breakdown_Flag1 := BintoInt(StrBits);
            if Debug in [9] then
               SalvaLog(Arq_Log, 'BreakDown Flag1: ' + StrBits);

            if (Length >= 2) then
            Begin
               // BreakDown Flag2
               StrBits := CharToStrBin(PacketRec, pInicial, 1);
               AcpBreakDown.Breakdown_Flag2 := BintoInt(StrBits);
               if Debug in [9] then
                  SalvaLog(Arq_Log, 'BreakDown Flag2: ' + StrBits);

               if StrBits[2] = '1' then
                  AcpBreakDown.Chave := 1
               Else
                  AcpBreakDown.Chave := 0;
            End;

            if (Length >= 3) then
            Begin
               // BreakDown Flag3
               StrBits := CharToStrBin(PacketRec, pInicial, 1);
               AcpBreakDown.Breakdown_Flag3 := BintoInt(StrBits);
               if Debug in [9] then
                  SalvaLog(Arq_Log, 'BreakDown Flag3: ' + StrBits);

               if StrBits[4] = '1' then // Main battery is reconnected
                  AcpBreakDown.Bateria_Religada := 1;
               if StrBits[5] = '1' then
                  AcpBreakDown.Bateria_Violada := 1;
            End;

            if (Length >= 4) then
            Begin
               // More flag = 1 means that there is additional breakdown sources flags defined by TCU suppliers.
               Begin
                  StrBits := CharToStrBin(PacketRec, pInicial, 1);
                  AcpBreakDown.Breakdown_Flag3 := BintoInt(StrBits);
               End;
            End;

            // More flag = 1 means that there is additional breakdown sources flags defined by TCU suppliers.
            if StrBits[1] = '1' then
            Begin
               StrBits := CharToStrBin(PacketRec, pInicial, 1);
               AcpBreakDown.Breakdown_Flag4 := BintoInt(StrBits);
            End;

         End
         Else if Length >= 1 then
         Begin

            for Contador := 1 to Length do
            Begin
               StrBits := CharToStrBin(PacketRec, pInicial, Length);
               AcpBreakDown.Breakdown_Data := AcpBreakDown.Breakdown_Data +
                  IntToHex(BintoInt(Copy(StrBits, 4, 5)), 2);
            End;

            if Debug in [9] then
               SalvaLog(Arq_Log, 'BreakDown Data: ' +
                  AcpBreakDown.Breakdown_Data);
         End;

      End;

      if (pInicial - PosInicio <> AcpBreakDown.Length + 1) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_BreakDown - Bytes processados / Deveria Processar: ' +
            InttoStr(pInicial - PosInicio) + '/' +
            InttoStr(AcpBreakDown.Length + 1));
         Corrigido := 6;
      End;
      Result := pInicial;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_BreakDown: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;

End;

Function Gravacao_Quanta_Acp.Decode_Information(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
//   TmpBytes: Word;
   Contador: Word;
   IEIdentifier: byte; // Para os parametros Opcionais
   more_Flag: byte; // Para os parametros Opcionais
   Length: byte; // Para os parametros Opcionais
Begin
Result  := pInicial;
   Try
      // Header Information
      StrBits := CharToStrBin(PacketRec, pInicial, 1);
      AcpInformation.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpInformation.more_Flag := StrtoInt(StrBits[3]);
      AcpInformation.Length := BintoInt(Copy(StrBits, 4, 5));

      if AcpInformation.Length > 0 then
      Begin
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpInformation.Information_Type := BintoInt(Copy(StrBits, 2, 7));

         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Length := BintoInt(Copy(StrBits, 4, 5));

         if Length >= 1 then
            for Contador := 1 to Length do
            Begin
               StrBits := CharToStrBin(PacketRec, pInicial, Length);
               AcpInformation.Information_RawData :=
                  AcpInformation.Information_RawData +
                  IntToHex(BintoInt(Copy(StrBits, 4, 5)), 2);
            End;

      End;
      Result := pInicial;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Information: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;

End;

Function Gravacao_Quanta_Acp.Decode_Message(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
Begin
Result  := pInicial;
   Try
      // MessageFields
      StrBits := CharToStrBin(PacketRec, pInicial, 3);

      AcpMessage.more_Flag := BintoInt(StrBits[1]);
      AcpMessage.TargetApplicationID := BintoInt(Copy(StrBits, 2, 7));
      AcpMessage.ApplFlag1 := BintoInt(Copy(StrBits, 9, 2));
      AcpMessage.ControlFlag1 := BintoInt(Copy(StrBits, 11, 6));
      AcpMessage.StatusFlag1 := BintoInt(Copy(StrBits, 17, 2));;
      AcpMessage.TCUResponseFlag := BintoInt(Copy(StrBits, 19, 2));
      AcpMessage.Reserved := BintoInt(Copy(StrBits, 21, 4));
      AcpMessage.Length := 3;
      Result := pInicial;
   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Message: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_Control_Function(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
Begin
Result := pInicial;
   Try
      // MessageFields
      StrBits := CharToStrBin(PacketRec, pInicial, 1);

      AcpControl_Function.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpControl_Function.more_Flag := StrtoInt(StrBits[3]);
      AcpControl_Function.Length := BintoInt(Copy(StrBits, 4, 5));

      if AcpControl_Function.Length >= 1 then
      Begin
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpControl_Function.Entity_ID := BintoInt(Copy(StrBits, 1, 8));
      End;

      if AcpControl_Function.Length >= 3 then
      Begin
         StrBits := CharToStrBin(PacketRec, pInicial, 2);
         AcpControl_Function.Reserved := BintoInt(Copy(StrBits, 1, 4));
         AcpControl_Function.Transmit_Units := BintoInt(Copy(StrBits, 5, 4));
         AcpControl_Function.Transmit_Interval :=
            BintoInt(Copy(StrBits, 9, 8));;
      End;

      Result := pInicial;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Control: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_Function_Command(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
   Contador: Word;
//   IEIdentifier: byte; // Para os parametros RawData
//   more_Flag: byte; // Para os parametros RawData
//   Length: byte; // Para os parametros RawData

Begin
Result := pInicial;
   Try
      // MessageFields
      StrBits := CharToStrBin(PacketRec, pInicial, 2);

      AcpFunction_Command.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpFunction_Command.more_Flag := StrtoInt(StrBits[3]);
      AcpFunction_Command.Length := BintoInt(Copy(StrBits, 4, 5));
      AcpFunction_Command.Command_or_Status := BintoInt(Copy(StrBits, 9, 8));

      // Raw Data
      if AcpFunction_Command.Length > 1 then
      Begin

         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpFunction_Command.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpFunction_Command.more_Flag := BintoInt(Copy(StrBits, 4, 5));
         AcpFunction_Command.Length := BintoInt(Copy(StrBits, 4, 5));
         if AcpFunction_Command.Length > 0 then
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial,
               AcpFunction_Command.Length);

            for Contador := 1 to AcpFunction_Command.Length do
               AcpFunction_Command.Raw_Data := AcpFunction_Command.Raw_Data +
                  StrBits[Contador] + ':';
         End;

      End;
      Result := pInicial;
   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Function_Command: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_Error(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;

Begin
Result := pInicial;
   Try
      // MessageFields
      StrBits := CharToStrBin(PacketRec, pInicial, 1);

      AcpError.IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpError.more_Flag := StrtoInt(StrBits[3]);
      AcpError.Length := BintoInt(Copy(StrBits, 4, 5));

      if AcpError.Length >= 1 then
      Begin
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpError.Error_Code := BintoInt(StrBits);
      End;

      if AcpError.Length > 1 then
      Begin
         StrBits := CharToStrBin(PacketRec, pInicial, AcpError.Length - 1);
      End;

      Result := pInicial;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Error: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;

End;

Function Gravacao_Quanta_Acp.Decode_TCU_Data_Error(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
   BytesTotal: Word;
   BytesLidos: Word;
   BytesRetorno: Word;
   Contador: Word;
   NumElementos: Word;
Begin
Result  := pInicial;
   Try
      {
        05 -- Decode_TCU_Data_Error - Length
        00 -- Data Type MSB
        11 -- Data Type LSB
        00 -- Length Data Type
        01 -- Configuration Data
        00 -- Error Element
      }
      // TCU_Data_Error
      StrBits := CharToStrBin(PacketRec, pInicial, 1);
      BytesLidos := 1;
      NumElementos := 1;
      SetLength(AcpDataError, NumElementos);

      AcpDataError[0].IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpDataError[0].more_Flag := StrtoInt(StrBits[3]);
      AcpDataError[0].Length := BintoInt(Copy(StrBits, 4, 5));
      BytesTotal := BintoInt(Copy(StrBits, 4, 5));

      SalvaLog(Arq_Log, 'Decode_TCU_Data_Error Length: ' +
         InttoStr(BytesTotal));

      while BytesLidos < BytesTotal do
      Begin

         StrBits := CharToStrBin(PacketRec, pInicial, 3);
         BytesLidos := BytesLidos + 3;

         AcpDataError[NumElementos - 1].Data_Type_MSB :=
            BintoInt(Copy(StrBits, 1, 8));
         AcpDataError[NumElementos - 1].Data_Type_LSB :=
            BintoInt(Copy(StrBits, 9, 8));
         AcpDataError[NumElementos - 1].Length_Data_Type :=
            BintoInt(Copy(StrBits, 17, 8));
         AcpDataError[NumElementos - 1].Configuration_Data := '';
         // Le os Error Element's

         BytesRetorno := AcpDataError[NumElementos - 1].Length_Data_Type;

         if BytesRetorno = 0 then
            BytesRetorno := 1;

         For Contador := 1 to BytesRetorno Do
         Begin
            StrBits := CharToStrBin(PacketRec, pInicial, 1);
            AcpDataError[NumElementos - 1].Configuration_Data :=
               AcpDataError[NumElementos - 1].Configuration_Data +
               IntToHex(BintoInt(Copy(StrBits, 1, 8)), 2);
         End;
         // Soma os bytes do parametro
         BytesLidos := BytesLidos + BytesRetorno;

         // Le o error Element
         StrBits := CharToStrBin(PacketRec, pInicial, 1);
         AcpDataError[NumElementos - 1].Error_Element :=
            BintoInt(Copy(StrBits, 1, 8));
         // Soma o byte lido
         BytesLidos := BytesLidos + 1;

         if BytesLidos < BytesTotal then
         Begin
            Inc(NumElementos);
            SetLength(AcpDataError, NumElementos);
         End;

      End;

      if (AcpVehicle.SIMCard_ID = Debug_ID) then
      Begin
         SalvaLog(Arq_Log, 'Decode_TCU_Data_Error Bytes lidos: ' +
            InttoStr(BytesLidos));
         StrBits := '';

         for Contador := pInicial to AcpHeader.Message_Length - 1 do
            StrBits := StrBits + IntToHex(PacketRec[Contador], 2);

         SalvaLog(Arq_Log, 'Decode_TCU_Data_Error Resto: ' + StrBits);
      End;

      Result := pInicial;

   Except
      SalvaLog(Arq_Log, 'Erro no Decode_TCU_Data_Error: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;
End;

Function Gravacao_Quanta_Acp.Decode_Reserved(Var pInicial: SmallInt): SmallInt;
Var
   StrBits: String;
Begin
Result  := pInicial;
   Try
      // MessageFields
      StrBits := CharToStrBin(PacketRec, pInicial, 1);
      Result  := pInicial;
   Except
      SalvaLog(Arq_Log, 'Erro no Decode_Reserved: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpHeader.Ok := False;
   End;
End;

Procedure Gravacao_Quanta_Acp.ZeraRecord;
Begin

   // header
   AcpHeader.Length := 0;
   AcpHeader.reserved1 := 0;
   AcpHeader.private_Flag1 := 0;
   AcpHeader.application_id := 0;
   AcpHeader.reserved2 := 0;
   AcpHeader.private_Flag2 := 0;
   AcpHeader.test_Flag := 0;
   AcpHeader.Message_type := 0;
   AcpHeader.version_Flag := 0;
   AcpHeader.application_version := 0;
   AcpHeader.Message_control_Flag0 := 0;
   AcpHeader.Message_control_Flag1 := 0;
   AcpHeader.Message_control_Flag2 := 0;
   AcpHeader.Message_control_Flag3 := 0;
   AcpHeader.Message_priority := 0;
   AcpHeader.more_Flag := 0;
   AcpHeader.Message_Length := 0;
   AcpHeader.Ok := False;

   // Version
   AcpVersion.Length := 0;
   AcpVersion.IEIdentifier := 0;
   AcpVersion.more_Flag := 0;
   AcpVersion.Car_Manufacturer := 0;
   AcpVersion.TCU_Manufacturer := 0;
   AcpVersion.Major_Hardware_Release := 0;
   AcpVersion.Major_Software_Release := 0;

   /// / TimeStamp
   AcpTimeStamp.Length := 0;
   AcpTimeStamp.Msg_DataHora := 0;

   /// / Location
   AcpLocation.IEIdentifier := 0;
   AcpLocation.more_Flag := 0;
   AcpLocation.Length := 0;

   /// / Location Current GPS
   AcpGPS_Current.IEIdentifier := 0;
   AcpGPS_Current.more_Flag := 0;
   AcpGPS_Current.Length := 0;
   AcpGPS_Current.Number_Satellites := 0;
   AcpGPS_Current.Atualizado := 0;

   /// / Location Current GPS Coding
   AcpGPS_Current_Coding.IEIdentifier := 0;
   AcpGPS_Current_Coding.more_Flag := 0;
   AcpGPS_Current_Coding.Length := 0;
   AcpGPS_Current_Coding.Location_Flag1 := 0;
   AcpGPS_Current_Coding.Location_Flag2 := 0;
   AcpGPS_Current_Coding.Angulo := 0;
   AcpGPS_Current_Coding.areatype := 0;
   AcpGPS_Current_Coding.locationtypecoding := 0;
   AcpGPS_Current_Coding.time_difference := 0;
   AcpGPS_Current_Coding.Longitude := 0;
   AcpGPS_Current_Coding.Latitude := 0;
   AcpGPS_Current_Coding.altitude := 0;
   AcpGPS_Current_Coding.Position_estimate_value := 0;
   AcpGPS_Current_Coding.Position_estimate_type := 0;
   AcpGPS_Current_Coding.heading_estimate_Type := 0;
   AcpGPS_Current_Coding.heading_estimate_value := 0;
   AcpGPS_Current_Coding.distance_Flag := 0;
   AcpGPS_Current_Coding.time_Flag := 0;
   AcpGPS_Current_Coding.Velocity := 0;

   /// / Location Prior GPS
   AcpGPS_Prior.IEIdentifier := 0;
   AcpGPS_Prior.more_Flag := 0;
   AcpGPS_Prior.Length := 0;
   AcpGPS_Prior.Number_Satellites := 0;
   AcpGPS_Prior.Atualizado := 0;

   /// / Location Prior GPS Coding
   AcpGPS_Prior_Coding.IEIdentifier := 0;
   AcpGPS_Prior_Coding.more_Flag := 0;
   AcpGPS_Prior_Coding.Length := 0;
   AcpGPS_Prior_Coding.Location_Flag1 := 0;
   AcpGPS_Prior_Coding.Location_Flag2 := 0;
   AcpGPS_Prior_Coding.Angulo := 0;
   AcpGPS_Prior_Coding.areatype := 0;
   AcpGPS_Prior_Coding.locationtypecoding := 0;
   AcpGPS_Prior_Coding.time_difference := 0;
   AcpGPS_Prior_Coding.Longitude := 0;
   AcpGPS_Prior_Coding.Latitude := 0;
   AcpGPS_Prior_Coding.altitude := 0;
   AcpGPS_Prior_Coding.Position_estimate_value := 0;
   AcpGPS_Prior_Coding.Position_estimate_type := 0;
   AcpGPS_Prior_Coding.heading_estimate_value := 0;
   AcpGPS_Prior_Coding.heading_estimate_Type := 0;
   AcpGPS_Prior_Coding.distance_Flag := 0;
   AcpGPS_Prior_Coding.time_Flag := 0;
   AcpGPS_Prior_Coding.Velocity := 0;

   // Current Dead Reckoning Data
   AcpCDRD_WGS84.IEIdentifier := 0;
   AcpCDRD_WGS84.more_Flag := 0;
   AcpCDRD_WGS84.Length := 0;
   AcpCDRD_WGS84.Latitude := 0;
   AcpCDRD_WGS84.Longitude := 0;

   // Array of Area Location Delta Coding
   AcpArea_Delta.IEIdentifier := 0;
   AcpArea_Delta.more_Flag := 0;
   AcpArea_Delta.Length := 0;

   // Vehicle
   AcpVehicle.IEIdentifier := 0;
   AcpVehicle.more_Flag := 0;
   AcpVehicle.Length := 0;
   AcpVehicle.Flag_Addl_Flag1 := 0;
   AcpVehicle.Flag_Language := 0;
   AcpVehicle.Flag_VIN := 0;
   AcpVehicle.Flag_TCU_Serial := 0;
   AcpVehicle.Flag_Vehicle_Color := 0;
   AcpVehicle.Flag_Vehicle_Model := 0;
   AcpVehicle.Flag_License_Plate := 0;
   AcpVehicle.Flag_IMEI := 0;
   AcpVehicle.Flag_Addl_Flag2 := 0;
   AcpVehicle.Flag_Vehicle_Model_year := 0;
   AcpVehicle.Flag_SIMCard_ID := 0;
   AcpVehicle.Flag_Auth_Key := 0;
   AcpVehicle.Language := '';
   AcpVehicle.VIN := '';
   AcpVehicle.TCU_Serial := 0;
   AcpVehicle.Vehicle_Color := '';
   AcpVehicle.Vehicle_Model := '';
   AcpVehicle.License_Plate := '';
   AcpVehicle.IMEI := '';
   AcpVehicle.Vehicle_Model_year := 0;
   AcpVehicle.SIMCard_ID := '';
   AcpVehicle.Auth_Key := '';

   // BreakDown
   AcpBreakDown.IEIdentifier := 0;
   AcpBreakDown.more_Flag := 0;
   AcpBreakDown.Length := 0;
   AcpBreakDown.Breakdown_Flag1 := 0;
   AcpBreakDown.Breakdown_Flag2 := 0;
   AcpBreakDown.Breakdown_Flag3 := 0;
   AcpBreakDown.Breakdown_Additional := 0;
   AcpBreakDown.Breakdown_sensor := 0;
   AcpBreakDown.Breakdown_Data := '';
   AcpBreakDown.Chave := 0;
   AcpBreakDown.Bateria_Violada := 0;
   AcpBreakDown.Bateria_Religada := 0;
   AcpBreakDown.Status := 0;

   // Information
   AcpInformation.IEIdentifier := 0;
   AcpInformation.more_Flag := 0;
   AcpInformation.Length := 0;
   AcpInformation.Information_Type := 0;
   AcpInformation.Information_RawData := '';

   // MessageFields
   AcpMessage.more_Flag := 0;
   AcpMessage.TargetApplicationID := 0;
   AcpMessage.ApplFlag1 := 0;
   AcpMessage.ControlFlag1 := 0;
   AcpMessage.StatusFlag1 := 0;
   AcpMessage.TCUResponseFlag := 0;
   AcpMessage.Reserved := 0;
   AcpMessage.Length := 0;

   // Control Function
   AcpControl_Function.IEIdentifier := 0;
   AcpControl_Function.more_Flag := 0;
   AcpControl_Function.Length := 0;
   AcpControl_Function.Entity_ID := 0;
   AcpControl_Function.Reserved := 0;
   AcpControl_Function.Transmit_Units := 0;
   AcpControl_Function.Transmit_Interval := 0;

   AcpDataError := nil;

End;

Procedure Gravacao_Quanta_Acp.Dormir(pTempo: SmallInt);
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



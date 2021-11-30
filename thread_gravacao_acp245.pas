unit thread_gravacao_acp245;

interface

uses
   Windows, SysUtils, Classes, Math, DB, DBClient, Types,
   ZConnection, ZDataset, ZAbstractRODataset,
   DateUtils, FuncColetor, FunAcp;

type
   gravacao_acp245 = class(TThread)

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
      CargaDisp: Boolean;
      // Objetos
      {
        QryBatch     : TZSqlProcessor;         //Um objeto query local
      }

      QryGeral     : TZReadOnlyQuery;        //Um objeto query local
      conn         : TZConnection;           //Uma tconnection local

   private
      { Private declarations }
      SqlTracking: String;
      SqlPendente: String;
      AcpRecebido: tAcpPacket;
      AcpDataError: Array Of tAcpDataError;
      AcpTCU_Data: Array of tAcpTCU_Data;
      PacketStr: String;
      PacketTot: TByteDynArray;
      PacketRec: TByteDynArray;
      Resposta: TByteDynArray;
      PosInicio: Word;
      PosLimite: Word;
      PosTotal: Word;
      Corrigido: Word;
   protected

      Processar: tClientDataSet;
      Processados: tClientDataSet;
      AcpTipos: tClientDataSet;
      Dispositivos: tClientDataSet;

      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaTracking;
      Function Decode: SmallInt;
      Function Decode_App02_03(Var PosInicio: Word): Word;
      Function Decode_App02_09(Var PosInicio: Word): Word;
      Function Decode_App06(Var PosInicio: Word): Word;
      Function Decode_App10(Var PosInicio: Word): Word;
      Function Decode_App11(Var PosInicio: Word): Word;
      Function Decode_Version(Var PosInicio: Word): Word;
      Function Decode_TimeStamp(Var PosInicio: Word): Word;
      Function Decode_Location(Var PosInicio: Word): Word;
      Function Decode_GPSRawData_Current(Var PosInicio: Word): Word;
      Function Decode_GPSRawData_Prior(Var PosInicio: Word): Word;
      Function Decode_Area_Location_Coding_Current(Var PosInicio: Word): Word;
      Function Decode_Area_Location_Coding_Prior(Var PosInicio: Word): Word;
      Function Decode_CDRD_WGS84(Var PosInicio: Word): Word;
      Function Decode_Area_Location_Delta(Var PosInicio: Word): Word;
      Function Decode_Vehicle(Var PosInicio: Word): Word;
      Function Decode_BreakDown(Var PosInicio: Word; pTipo_App: Integer): Word;
      Function Decode_Information(Var PosInicio: Word): Word;
      Function Decode_Message(Var PosInicio: Word): Word;
      Function Decode_Control_Function(Var PosInicio: Word): Word;
      Function Decode_Function_Command(Var PosInicio: Word): Word;
      Function Decode_Error(Var PosInicio: Word): Word;
      Function Decode_TCU_Data_Error(Var PosInicio: Word): Word;
      Function Decode_TCU_Descriptor(Var PosInicio: Word): Word;
      Function Decode_Reserved(Var PosInicio: Word): Word;
      Function  CargaDispositivos():Boolean;
      Function  AtualizaDispositivos(pID: String):Boolean;
      Function  GravaDispositivos():Boolean;
      Procedure ZeraRecord;
      Procedure Dormir(pTempo: Word);
      Procedure CargaACP;

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure gravacao_acp245.Execute;
begin
   Try
      // CarregaValores;
      Conn                 := TZConnection.Create(nil);
      QryGeral             := TZReadOnlyQuery.Create(Nil);
      conn.HostName        := db_hostname;
      conn.User            := db_username;
      conn.Password        := db_password;
      conn.Database        := db_database;
      conn.Protocol        := 'mysql';
      conn.Port            := 3306;
      conn.Properties.Add('sort_buffer_size=8192');
      QryGeral.Connection := conn;

      SqlTracking := 'insert into nexsat.' + db_tablecarga + ' ';
      SqlTracking := SqlTracking +
         '(id, data_rec, dh_gps, latitude, longitude, porta, ip_remoto, porta_remoto, velocidade, angulo, qtdade_satelite, atualizado, chave, bateria_violada, bateria_religada, breakdown1, breakdown2, breakdown3, breakdown4, marc_codigo) ';


      Processar := tClientDataSet.Create(nil);
      Processar.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processar.FieldDefs.Add('IP', ftString, 15, False);
      Processar.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processar.FieldDefs.Add('ID', ftString, 20, False);
      Processar.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Processar.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Processar.FieldDefs.Add('Processado', ftBoolean, 0, False);
      Processar.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      Processar.FieldDefs.Add('Data_rec', ftDateTime, 0, False);
      Processar.CreateDataSet;

      Processados := tClientDataSet.Create(nil);
      Processados.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processados.FieldDefs.Add('IP', ftString, 15, False);
      Processados.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processados.FieldDefs.Add('ID', ftString, 20, False);
      Processados.FieldDefs.Add('Resposta', ftBlob, 0, False);
      Processados.CreateDataSet;

      AcpTipos := tClientDataSet.Create(nil);
      AcpTipos.FieldDefs.Add('chave', ftInteger, 0, False);
      AcpTipos.FieldDefs.Add('codigo', ftInteger, 0, False);
      AcpTipos.FieldDefs.Add('descricao', ftString, 40, False);
      AcpTipos.CreateDataSet;

      Dispositivos :=  tClientDataSet.Create(nil);
      dispositivos.fielddefs.add('id', ftstring,20, false);
      dispositivos.fielddefs.add('car_manufacturer', ftinteger, 0, false);
      dispositivos.fielddefs.add('tcu_manufacturer', ftinteger, 0, false);
      dispositivos.fielddefs.add('hardware_release', ftinteger, 0, false);
      dispositivos.fielddefs.add('software_release', ftinteger, 0, false);
      dispositivos.fielddefs.add('vehicle_vin_number', ftstring,20, false);
      dispositivos.fielddefs.add('vehicle_tcu_serial', ftstring,20, false);
      dispositivos.fielddefs.add('vehicle_flag1', ftstring,20, false);
      dispositivos.fielddefs.add('vehicle_flag2', ftstring,20, false);
      dispositivos.fielddefs.add('language', ftstring,20, false);
      dispositivos.fielddefs.add('model_year', ftinteger, 0, false);
      dispositivos.fielddefs.add('vin', ftstring,20, false);
      dispositivos.fielddefs.add('tcu_serial', ftstring,20, false);
      dispositivos.fielddefs.add('license_plate', ftstring,10, false);
      dispositivos.fielddefs.add('vehicle_color', ftstring,20, false);
      dispositivos.fielddefs.add('vehicle_model', ftstring,20, false);
      dispositivos.fielddefs.add('imei', ftstring,20, false);
      dispositivos.fielddefs.add('sim_card_id', ftstring,20, false);
      dispositivos.fielddefs.add('auth_key', ftstring,20, false);
      dispositivos.fielddefs.add('device_id', ftstring,20, false);
      dispositivos.fielddefs.add('version_id', ftstring,20, false);
      dispositivos.fielddefs.add('host1', ftstring,15, false);
      dispositivos.fielddefs.add('porta1', ftinteger, 0, false);
      dispositivos.fielddefs.add('protocolo1', ftstring,3, false);
      dispositivos.fielddefs.add('host2', ftstring,15, false);
      dispositivos.fielddefs.add('porta2', ftinteger, 0, false);
      dispositivos.fielddefs.add('protocolo2', ftstring,3, false);
      dispositivos.fielddefs.add('operadora', ftstring,20, false);
      dispositivos.fielddefs.add('application_version', ftinteger, 0, false);
      dispositivos.fielddefs.add('message_control', ftinteger, 0, false);
      dispositivos.fielddefs.add('modificado', ftinteger, 0, false);
      dispositivos.CreateDataSet;

      Try
         conn.Connect;
      Except
         SalvaLog(Arq_Log,'Erro ao conectar com o Banco de Dados - Thread: ' + InttoStr(ThreadId));
      End;


      while Not Encerrar do
      Begin

         Try
            if (Not conn.PingServer) then
            Begin
               conn.Disconnect;
               conn.Connect;
            End;
         Except
            SalvaLog(Arq_Log, 'Erro ao "pingar" o MySql (Thread): ' +
               InttoStr(ThreadId));
            Dormir(15000);
            Continue;
         End;

         if (Not CargaDisp) then
            Try
               CargaDisp := CargaDispositivos();
            Except
               SalvaLog(Arq_Log,'Erro ao conectar com o Banco de Dados - Thread: ' + InttoStr(ThreadId));
            End;


         Arq_Log := ExtractFileDir(Arq_Log) + '\' + FormatDateTime('yyyy-mm-dd',
            now) + '.log';

         TcpSrvForm.Thgravacao_acp245_ultimo := now;

         if (Not conn.PingServer) or (Not CargaDisp) then
         Try
            conn.Disconnect;
            conn.Connect;
            CargaDisp  := CargaDispositivos();
         Except
            SalvaLog(Arq_Log,'Erro ao "pingar" o MySql: ' );
            Dormir(1000);
            Continue;
         End;

         if (Not conn.Connected) or (Not CargaDisp) then
         Try
            conn.Disconnect;
            conn.Connect;
            CargaDisp  := CargaDispositivos();
         Except
            SalvaLog(Arq_Log,'Erro ao conectar com o MySql: ' );
            Dormir(1000);
            Continue;
         End;

         BuscaArquivo;

         if (Arq_inbox <> '') then
            GravaTracking
         Else
         Begin
            Dormir(50);
         End;

      End;


      QryGeral.Close;
      conn.Disconnect;
      QryGeral.Free;
      conn.Free;

      Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Gravação ACP - Encerrada por Erro: ' + InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;
end;

Procedure gravacao_acp245.BuscaArquivo;
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

Procedure gravacao_acp245.GravaTracking;
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
   BitsBreakDown: String;
//   ContTrack: Word;
   ContErros: Word;

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

   If Not Processados.Active Then
      Processados.Open;

   Processados.EmptyDataSet;
   tInicio := now;

   while Not Processar.Eof do
   Begin

      erro := False;

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

      TipoPacket := 0;

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
               'insert into acp245.acp_recebidos (id, data_rec, tipo, duplicado, ip_origem, pacote) values (';
            SqlExec := SqlExec + QuotedStr(Processar.FieldByName('ID')
               .AsString) + ',';
            SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',Processar.FieldByName('Data_rec').AsDateTime))+ ',';
            SqlExec := SqlExec + '0,';
            SqlExec := SqlExec + InttoStr(Processar.FieldByName('Duplicado')
               .AsInteger) + ',';
            SqlExec := SqlExec + 'Select INET_ATON(' +
               QuotedStr(Processar.FieldByName('IP').AsString) + '),';
            SqlExec := SqlExec + QuotedStr(inttoStr(PortaLocal) + ' : ' + PacketStr) + ');';
            SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
            Continue;
         End;

         { if (TipoPacket <> 99) and (AcpRecebido.Header_Ok = True) then
           Begin
           SqlExec := 'insert into acp245.acp_recebidos values (';
           SqlExec := SqlExec +  QuotedStr(Copy(Trim(Processar.FieldByName('ID').AsString) + AcpVehicle.SIMCard_ID,1,20)) + ',';
           SqlExec := SqlExec +  'now(),' ;
           SqlExec := SqlExec +  InttoStr(TipoPacket) + ',';
           SqlExec := SqlExec +  QuotedStr(PacketStr) + ');';
           SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
           End
           Else }
         if (Not AcpRecebido.Header_Ok) or
            (Processar.FieldByName('Duplicado').AsInteger = 1) or (Corrigido > 0)
         then
         Begin
            SqlExec :=
               'insert into acp245.acp_recebidos (id, data_rec, tipo, duplicado, ip_origem, pacote) values (';
            SqlExec := SqlExec +
               QuotedStr(Copy(Trim(Processar.FieldByName('ID').AsString) +
               AcpRecebido.Vehicle_SIMCard_ID, 1, 20)) + ',';
            SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',Processar.FieldByName('Data_rec').AsDateTime))+ ',';
            SqlExec := SqlExec + '0,';
            if Processar.FieldByName('Duplicado').AsInteger = 1 then
               SqlExec := SqlExec + InttoStr(Processar.FieldByName('Duplicado')
                  .AsInteger) + ','
            Else
               SqlExec := SqlExec + InttoStr(Corrigido) + ',';

            SqlExec := SqlExec + 'INET_ATON(' +
               QuotedStr(Processar.FieldByName('IP').AsString) + '),';
            SqlExec := SqlExec + QuotedStr(inttoStr(PortaLocal) + ' : ' + PacketStr) + ');';
            SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
         End;

         if (TipoPacket = 99) then
         Begin
            SetLength(PacketTot, 0);
            Continue
         End
         Else if (Not AcpRecebido.Header_Ok) then
         Begin
            SetLength(PacketTot, 0);
            erro := True;
            Inc(ContErros);
            Continue;
         End;

         // Se o ID For Branco - Acabou de Logar
         // Grava os dados do TCU
         if (Not erro) and (Processar.FieldByName('ID').AsString = '') and
            (AcpRecebido.Vehicle_SIMCard_ID <> '')
         then
         Begin

            SqlExec := 'Call nexsat.atualiza_acp245_data(';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ',';
            SqlExec := SqlExec + InttoStr(AcpRecebido.Version_Car_Manufacturer) + ',';
            SqlExec := SqlExec + InttoStr(AcpRecebido.Version_TCU_Manufacturer) + ',';
            SqlExec := SqlExec +
               InttoStr(AcpRecebido.Version_Major_Hardware_Release) + ',';
            SqlExec := SqlExec +
               InttoStr(AcpRecebido.Version_Major_Software_Release) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_Language) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_VIN) + ',';
            SqlExec := SqlExec + InttoStr(AcpRecebido.Vehicle_TCU_Serial) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_Vehicle_Color) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_Vehicle_Model) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_License_Plate) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_IMEI) + ',';
            SqlExec := SqlExec + InttoStr(AcpRecebido.Vehicle_Vehicle_Model_year) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ',';
            SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_Auth_Key) + ');';

            SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

         End;

         // Salva o Id Decodificado
         if (Not erro) and (TipoPacket > 0) and (AcpRecebido.Vehicle_SIMCard_ID <> '')
            and (((now - FileDate) * 60 * 24) <= 5) and (now > ServerStartUp)
            then
            Try
               Processados.Insert;
               Processados.FieldByName('ID').AsString := AcpRecebido.Vehicle_SIMCard_ID;
               Processados.FieldByName('IP').AsString :=
                  Processar.FieldByName('IP').AsString;
               Processados.FieldByName('Porta').AsString :=
                  Processar.FieldByName('Porta').AsString;
               Processados.FieldByName('Tcp_Client').AsString :=
                  Processar.FieldByName('Tcp_Client').AsString;
               if Length(Resposta) > 0 then
               Begin
                  StreamRes := TMemoryStream.Create;
                  ByteArrayToStream(Resposta, StreamRes);
                  blobR := Processados.FieldByName('Resposta') as TBlobField;
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
               Processados.Post;

            Except
               SalvaLog(Arq_Log, 'Erro ao Inserir Resposta: ');
               erro := True;
               Inc(ContErros);
               Continue;
            End;

         If (Not erro) and (TipoPacket in [10, 11]) and
            (AcpRecebido.Vehicle_SIMCard_ID <> '') and
            (AcpRecebido.Header_Ok) then

            Try


               SqlExec := SqlTracking;
               SqlExec := SqlExec + 'Values(';
               SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
               SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',Processar.FieldByName('Data_rec').AsDateTime))+ ',';
               SqlExec := SqlExec + 'DATE_SUB( ' +
                  QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',
                  AcpRecebido.TimeStamp_Msg_DataHora)) +
                  ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
               SqlExec := SqlExec +
                  Troca(FormatFloat('###0.######',
                  AcpRecebido.GPS_Current_Coding_Latitude)) + ', ';
               SqlExec := SqlExec +
                  Troca(FormatFloat('###0.######',
                  AcpRecebido.GPS_Current_Coding_Longitude)) + ', ';
               SqlExec := SqlExec + InttoStr(PortaLocal) + ', ';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('IP')
                  .AsString) + ', ';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('Porta')
                  .AsString) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.GPS_Current_Coding_Velocity) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.GPS_Current_Angulo) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.GPS_Current_RawData_Number_Satellites) + ', ';
               SqlExec := SqlExec + InttoStr(AcpRecebido.GPS_Current_Atualizado) + ', ';
               SqlExec := SqlExec + InttoStr(AcpRecebido.BreakDown_Chave) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.BreakDown_Bateria_Violada) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.BreakDown_Bateria_Religada) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.BreakDown_Breakdown_Flag1) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.BreakDown_Breakdown_Flag2) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.BreakDown_Breakdown_Flag3) + ', ';
               SqlExec := SqlExec +
                  InttoStr(AcpRecebido.BreakDown_Breakdown_Flag4) + ', ';
               SqlExec := SqlExec + '27';
               SqlExec := SqlExec + ');';

               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

               if (AcpRecebido.BreakDown_Breakdown_Flag1 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpRecebido.BreakDown_Breakdown_Flag1);
                  for Contador := 2 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DATA_REC, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
                        SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',Processar.FieldByName('Data_rec').AsDateTime))+ ',';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpRecebido.TimeStamp_Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_1') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if (AcpRecebido.BreakDown_Breakdown_Flag2 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpRecebido.BreakDown_Breakdown_Flag2);
                  for Contador := 2 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DATA_REC, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
                        SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',Processar.FieldByName('Data_rec').AsDateTime))+ ',';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpRecebido.TimeStamp_Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_2') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if (AcpRecebido.BreakDown_Breakdown_Flag3 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpRecebido.BreakDown_Breakdown_Flag3);
                  for Contador := 2 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DATA_REC, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
                        SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',Processar.FieldByName('Data_rec').AsDateTime))+ ',';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpRecebido.TimeStamp_Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_3') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if (AcpRecebido.BreakDown_Breakdown_Flag4 > 0)  then
               Begin
                  BitsBreakDown := IntToStrBin(AcpRecebido.BreakDown_Breakdown_Flag4);
                  for Contador := 2 to 8 do
                  Begin
                     if Copy(BitsBreakDown,Contador,1) = '1' then
                     Begin
                        SqlExec := 'Insert ignore into nexsat.eventos (ID, DATA_REC, DH_GPS, TIPO, CODIGO) Values (';
                        SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
                        SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',Processar.FieldByName('Data_rec').AsDateTime))+ ',';
                        SqlExec := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpRecebido.TimeStamp_Msg_DataHora)) + ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec := SqlExec + QuotedStr('BREAKDOWN_4') + ', ';
                        SqlExec := SqlExec + inttoStr(Contador-1) + ');' ;
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                     End;
                  End;
               End;

               if AcpRecebido.BreakDown_Bateria_Religada = 1 then
               Begin
                  SqlExec := 'call recebe_parametros_cpr(';
                  SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
                  SqlExec := SqlExec + QuotedStr('BATERIA') + ',' +
                     QuotedStr('RELIGADA') + '); ';
                  SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
               End;
               if AcpRecebido.BreakDown_Bateria_Violada = 1 then
               Begin
                  SqlExec := 'call recebe_parametros_cpr(';
                  SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
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
            (AcpRecebido.Vehicle_SIMCard_ID <> '')
         then
            Try
               //
               if Length(AcpDataError) = 0 then
               Begin
                  // So tem 1 error
                  SqlExec := 'Replace into nexsat.dispositivos_status (ID, PARAM, VALOR, DT_ULTIMA, ENVI_REMOTO) Values(';
                  SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
                  SqlExec := SqlExec + QuotedStr('PARAMETER_ERROR') + ',';
                  SqlExec := SqlExec + QuotedStr(InttoStr(AcpRecebido.Error_Code));
                  SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', now())) + ',0);' ;

                  SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

               End
               Else
               Begin
                  SalvaLog(Arq_Log, 'Tamanho do vetor AcpDataError ' +
                     InttoStr(Length(AcpDataError)) + ' ! ID:' +
                     AcpRecebido.Vehicle_SIMCard_ID + ' - ' + PacketStr);
                  // Multiplos erros
                  for Contador := 0 to Length(AcpDataError) - 1 do
                  Begin
                     SqlExec := 'call recebe_parametros_cpr(';
                     SqlExec := SqlExec +
                        QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
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
                  + ' Where id = ' + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) +
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
            (AcpRecebido.Vehicle_SIMCard_ID <> '') and
            (AcpRecebido.Header_Ok) then
            Try

               SqlExec := 'Replace into nexsat.dispositivos_status (ID, PARAM, VALOR, DT_ULTIMA, ENVI_REMOTO) Values(';
               SqlExec := SqlExec + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) + ', ';
               SqlExec := SqlExec + QuotedStr('CONTROL_ENTITY_' + InttoStr(AcpRecebido.Control_Function_Entity_ID)) + ',';
               SqlExec := SqlExec + QuotedStr(InttoStr(AcpRecebido.Function_Command_Command_or_Status));
               SqlExec := SqlExec + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', now())) + ',0);' ;
               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

               SqlExec :=
                  'Update nexsat.comandos_envio Set Status = 3, dt_envio = now()'
                  + ' Where id = ' + QuotedStr(AcpRecebido.Vehicle_SIMCard_ID) +
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
            if (Debug In [2, 5, 9]) or (AcpRecebido.Vehicle_SIMCard_ID = Debug_ID) then
            Begin
               if not erro then
                  SalvaLog(Arq_Log, 'Não Salvou o Pacote: ' +
                     InttoStr(TipoPacket) + ':' + AcpRecebido.Vehicle_SIMCard_ID)
               Else
                  SalvaLog(Arq_Log, 'Pacote Com erro ! Não Salvou o Pacote: ' +
                     InttoStr(TipoPacket) + ':' + AcpRecebido.Vehicle_SIMCard_ID);
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

   if (Debug In [2, 5, 9]) or (AcpRecebido.Vehicle_SIMCard_ID = Debug_ID) then
      SalvaLog(Arq_Log, 'Tempo execução Decode: ' + FormatDateTime('ss:zzz',
         tFinal - tInicio) + ' Segundos');

   Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_inbox);
   Arq_Err   := DirErros + '\' + ExtractFileName(Arq_inbox);
   Arq_Sql   := DirSql + '\' + ExtractFileName(Arq_inbox);

   tInicio := now;
//   SqlPendente := SqlPendente + GeraSqlStatus(PortaLocal, ContTrack, ContTrack, ContErros, -1);

   SalvaArquivo(Arq_Sql, SqlPendente);

   {

     {

     AtualizaStatus(PortaLocal, ContTrack, ContTrack, ContErros, -1, Arq_Log, QryGeral ) ;
     If not ExecutarBatch(SqlPendente, Arq_Log, QryBatch) Then
     Begin
     SalvaLog(Arq_Log,'Erro ao executar sql batch: ' + Arq_Sql );
     SalvaArquivo( Arq_Sql, SqlPendente);
     End;
   }

   tFinal := now;

   if (Debug In [2, 5, 9]) or (AcpRecebido.Vehicle_SIMCard_ID = Debug_ID) then
      SalvaLog(Arq_Log, 'Tempo execução Sql batch: ' + Arq_inbox + ' - ' +
         FormatDateTime('ss:zzz', tFinal - tInicio) + ' Segundos');

   Try
      Processados.SaveToFile(Arq_Proce);
      Processados.Close;
   Except
      SalvaLog(Arq_Log, 'Erro ao Salvar arquivo processados: ' + Arq_Proce);
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

Function gravacao_acp245.Decode: SmallInt;
Var
   Posicao: Word;
   StrBits: String;
   Contador: Word;
   Resto: Word;
   Processado: Word;
   LogStr: String;

Begin

   Try

      Corrigido := 0;
      PosLimite := 3;
      Posicao   := 0;

      SetLength(Resposta, 0);

      if Length(PacketTot) < 3 then
      Begin
         SetLength(PacketTot, 0);
         Result := 0;
         Exit;
      End;

      // Header do Pacote
      // le 3 Bytes para saber se exist o 4 (Opcional)
      StrBits := CharToStrBinLimit(PacketTot, Posicao, PosLimite, 3);
      AcpRecebido.Header_Length := 3;

      AcpRecebido.Header_reserved1             := StrtoIntDef(StrBits[1],0);
      AcpRecebido.Header_private_Flag1         := StrtoIntDef(StrBits[2],0);
      AcpRecebido.Header_application_id        := BintoInt(Copy(StrBits, 3, 6));

      AcpRecebido.Header_reserved2             := StrtoIntDef(StrBits[9],0);
      AcpRecebido.Header_private_Flag2         := StrtoIntDef(StrBits[10],0);
      AcpRecebido.Header_test_Flag             := StrtoIntDef(StrBits[11],0);
      AcpRecebido.Header_Message_type          := BintoInt(Copy(StrBits, 12, 5));
      AcpRecebido.Header_version_Flag          := StrtoIntDef(StrBits[17],0);
      AcpRecebido.Header_version               := BintoInt(Copy(StrBits, 18, 3));
      AcpRecebido.Header_Message_control_Flag0 := StrtoIntDef(StrBits[21],0);
      AcpRecebido.Header_Message_control_Flag1 := StrtoIntDef(StrBits[22],0);
      AcpRecebido.Header_Message_control_Flag2 := StrtoIntDef(StrBits[23],0);
      AcpRecebido.Header_Message_control_Flag3 := StrtoIntDef(StrBits[24],0);

      // Se o version Flag =1 tem +1 byte no header
      if AcpRecebido.Header_version_Flag = 1 then
      Begin
         PosLimite                             := PosLimite + 1;
         StrBits                               := CharToStrBinLimit(PacketTot, Posicao, PosLimite, 1);
         AcpRecebido.Header_Length             := AcpRecebido.Header_Length + 1;
         AcpRecebido.Header_more_Flag          := StrtoInt(StrBits[1]);
         AcpRecebido.Header_Message_priority   := BintoInt(Copy(StrBits, 7, 2));
      End;

      if AcpRecebido.Header_Message_control_Flag2 = 0 then
      // 0 = The message Length field is 8 bits
      Begin
         PosLimite                             := PosLimite + 1;
         StrBits                               := CharToStrBinLimit(PacketTot, Posicao, PosLimite, 1);
         AcpRecebido.Header_Length             := AcpRecebido.Header_Length + 1;
         AcpRecebido.Header_Message_Length     := BintoInt(Copy(StrBits, 1, 8));
      End
      Else if AcpRecebido.Header_Message_control_Flag2 = 1 then
      // 1=The message Length field is 16 bits
      Begin
         PosLimite                             := PosLimite + 2;
         StrBits                               := CharToStrBinLimit(PacketTot, Posicao, PosLimite, 2);
         AcpRecebido.Header_Length             := AcpRecebido.Header_Length + 2;
         AcpRecebido.Header_Message_Length := BintoInt(Copy(StrBits, 1, 16));
      End;

      AcpRecebido.Header_Ok := True;

      Result := AcpRecebido.Header_application_id;

      Processado    := AcpRecebido.Header_Message_Length;
      if Processado > Length(PacketTot) then
         Processado := Length(PacketTot);

      // Tipo Mensagem = 0
      if (AcpRecebido.Header_Message_type = 0) then
      Begin
         Result := 0;
         SetLength(PacketTot, 0);
         Exit;
      End
      // Tamanho do Header maior que os dados passsados
      Else if (AcpRecebido.Header_Message_Length > Length(PacketTot)) then
      Begin
         Result := 0;
         SetLength(PacketTot, 0);
         Exit;
      End
      // Tipo application_id = 0
      Else if Not(AcpRecebido.Header_application_id in [2, 6, 10, 11]) then
      Begin
         Result := 0;
         SetLength(PacketTot, 0);
         Exit;
      End
      // Keep Alive
      Else if (AcpRecebido.Header_application_id = 11) and (AcpRecebido.Header_Message_type = 4)
      then
      Begin

         If (AcpRecebido.Header_Message_control_Flag3 = 1) Then
         Begin
            SetLength(Resposta, 4);
            // 1 Byte Application ID
            Resposta[0] :=
               BintoInt('0' + Copy(IntToStrBin(AcpRecebido.Header_private_Flag1), 8, 1) +
               Copy(IntToStrBin(AcpRecebido.Header_application_id), 3, 6));
            // 2 Byte MessageType = 2 = Theft Alarm Reply
            Resposta[1] :=
               BintoInt('0' + Copy(IntToStrBin(AcpRecebido.Header_private_Flag2), 8, 1) +
               Copy(IntToStrBin(AcpRecebido.Header_test_Flag), 8, 1) +
               Copy(IntToStrBin(5), 5, 4));
            // 3 Byte Application Version  + Message Control Flag
            Resposta[2] := BintoInt(Copy(IntToStrBin(AcpRecebido.Header_version_Flag), 8,
               1) + Copy(IntToStrBin(AcpRecebido.Header_version), 6, 3)
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
      Resto := Length(PacketTot) - AcpRecebido.Header_Message_Length;

      for Contador := Processado to Processado + Resto - 1 do
         PacketTot[Contador - Processado] := PacketTot[Contador];

      SetLength(PacketTot, Resto);

      // APP ID = 2 & Message Type = 3
      if (AcpRecebido.Header_application_id = 2) and (AcpRecebido.Header_Message_type = 3) then
      Begin
         Posicao := Posicao + Decode_App02_03(Posicao);
         If debug >= 5 Then
            SalvaLog(Arq_Log, 'Decode_App02_03 - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));
      End

      // APP ID = 2 & Message Type = 9
      Else if (AcpRecebido.Header_application_id = 2) and (AcpRecebido.Header_Message_type = 9)
      then
      Begin
         Posicao := Posicao + Decode_App02_09(Posicao);
         If debug >= 5 Then
            SalvaLog(Arq_Log, 'Decode_App02_09 - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));
      End
      // APP ID = 6
      Else if AcpRecebido.Header_application_id = 6 then
      Begin
         Posicao := Posicao + Decode_App06(Posicao);
         If debug >= 5 Then
            SalvaLog(Arq_Log, 'Decode_App06 - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));
      End
      // APP ID = 10
      Else if (AcpRecebido.Header_application_id = 10) then
      Begin

         Posicao := Posicao + Decode_App10(Posicao);
         If debug >= 5 Then
            SalvaLog(Arq_Log, 'Decode_App10 - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

         if (AcpRecebido.Header_Message_control_Flag3 = 1) then
         Begin
            SetLength(Resposta, 13);
            // 1 Byte Application ID
            Resposta[0] :=
               BintoInt('0' + Copy(IntToStrBin(AcpRecebido.Header_private_Flag1), 8, 1) +
               Copy(IntToStrBin(AcpRecebido.Header_application_id), 3, 6));
            // 2 Byte MessageType = 3 = Theft Alarm Reply
            Resposta[1] :=
               BintoInt('0' + Copy(IntToStrBin(AcpRecebido.Header_private_Flag2), 8, 1) +
               Copy(IntToStrBin(AcpRecebido.Header_test_Flag), 8, 1) +
               Copy(IntToStrBin(3), 4, 5));
            // 3 Byte Application Version  + Message Control Flag
            Resposta[2] := BintoInt(Copy(IntToStrBin(AcpRecebido.Header_version_Flag), 8,
               1) + Copy(IntToStrBin(AcpRecebido.Header_version), 6, 3)
               + '0000');
            // 4 Byte Message length
            Resposta[3] := 13;
            // 5 Byte Version Element - Header (4 = Length of Version Element)
            Resposta[4] := 4;
            // 6 Byte Version Element - Car Manufacturer ID
            Resposta[5] := AcpRecebido.Version_Car_Manufacturer;
            // 7 Byte Version Element - Car Manufacturer ID
            Resposta[6] := AcpRecebido.Version_TCU_Manufacturer;
            // 8 Byte Version Element - Major hardware release
            Resposta[7] := AcpRecebido.Version_Major_Hardware_Release;
            // 9 Byte Version Element - Major hardware release
            Resposta[8] := AcpRecebido.Version_Major_Software_Release;
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
      Else if (AcpRecebido.Header_application_id = 11) then
      Begin

         Posicao := Posicao + Decode_App11(Posicao);
         If debug >= 5 Then
            SalvaLog(Arq_Log, 'Decode_App11 - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

         if (AcpRecebido.Header_Message_control_Flag3 = 1) then
         Begin
            SetLength(Resposta, 13);
            // 1 Byte Application ID
            Resposta[0] :=
               BintoInt('0' + Copy(IntToStrBin(AcpRecebido.Header_private_Flag1), 8, 1) +
               Copy(IntToStrBin(AcpRecebido.Header_application_id), 3, 6));
            // 2 Byte MessageType = 2 = Theft Alarm Reply
            Resposta[1] :=
               BintoInt('0' + Copy(IntToStrBin(AcpRecebido.Header_private_Flag2), 8, 1) +
               Copy(IntToStrBin(AcpRecebido.Header_test_Flag), 8, 1) +
               Copy(IntToStrBin(2), 4, 5));
            // 3 Byte Application Version  + Message Control Flag
            Resposta[2] := BintoInt(Copy(IntToStrBin(AcpRecebido.Header_version_Flag), 8,
               1) + Copy(IntToStrBin(AcpRecebido.Header_version), 6, 3)
               + '0000');
            // 4 Byte Message length
            Resposta[3] := 13;
            // 5 Byte Version Element - Header (4 = Length of Version Element)
            Resposta[4] := 4;
            // 6 Byte Version Element - Car Manufacturer ID
            Resposta[5] := AcpRecebido.Version_Car_Manufacturer;
            // 7 Byte Version Element - Car Manufacturer ID
            Resposta[6] := AcpRecebido.Version_TCU_Manufacturer;
            // 8 Byte Version Element - Major hardware release
            Resposta[7] := AcpRecebido.Version_Major_Hardware_Release;
            // 9 Byte Version Element - Major hardware release
            Resposta[8] := AcpRecebido.Version_Major_Software_Release;
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

      End
      Else
      Begin
         SalvaLog(Arq_Log, 'Não decodificou (1): ' + PacketStr);
         SetLength(PacketTot, 0);
         Result := 0;
         AcpRecebido.Header_Ok := False;
      End;

      if ( Debug  >= 5 )  then
      Begin

         LogStr := 'Header_Length: ' + InttoStr(AcpRecebido.Header_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Reserved1: ' + InttoStr(AcpRecebido.Header_Reserved1) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Private_Flag1: ' + InttoStr(AcpRecebido.Header_Private_Flag1) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Application_Id: ' + InttoStr(AcpRecebido.Header_Application_Id) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Reserved2: ' + InttoStr(AcpRecebido.Header_Reserved2) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Private_Flag2: ' + InttoStr(AcpRecebido.Header_Private_Flag2) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Test_Flag: ' + InttoStr(AcpRecebido.Header_Test_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Message_Type: ' + InttoStr(AcpRecebido.Header_Message_Type) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Version: ' + InttoStr(AcpRecebido.Header_Version) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Version_Flag: ' + InttoStr(AcpRecebido.Header_Version_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Message_Control_Flag0: ' + InttoStr(AcpRecebido.Header_Message_Control_Flag0) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Message_Control_Flag1: ' + InttoStr(AcpRecebido.Header_Message_Control_Flag1) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Message_Control_Flag2: ' + InttoStr(AcpRecebido.Header_Message_Control_Flag2) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Message_Control_Flag3: ' + InttoStr(AcpRecebido.Header_Message_Control_Flag3) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Message_Priority: ' + InttoStr(AcpRecebido.Header_Message_Priority) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_More_Flag: ' + InttoStr(AcpRecebido.Header_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Message_Length: ' + InttoStr(AcpRecebido.Header_Message_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Header_Ok: ' + BoolToStr(AcpRecebido.Header_Ok) + Char(13) + Char(10);
         LogStr := LogStr + 'Version_Length: ' + InttoStr(AcpRecebido.Version_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Version_IEIdentifier: ' + InttoStr(AcpRecebido.Version_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Version_More_Flag: ' + InttoStr(AcpRecebido.Version_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Version_Car_Manufacturer: ' + InttoStr(AcpRecebido.Version_Car_Manufacturer) + Char(13) + Char(10);
         LogStr := LogStr + 'Version_TCU_Manufacturer: ' + InttoStr(AcpRecebido.Version_TCU_Manufacturer) + Char(13) + Char(10);
         LogStr := LogStr + 'Version_Major_Hardware_Release: ' + InttoStr(AcpRecebido.Version_Major_Hardware_Release) + Char(13) + Char(10);
         LogStr := LogStr + 'Version_Major_Software_Release: ' + InttoStr(AcpRecebido.Version_Major_Software_Release) + Char(13) + Char(10);
         LogStr := LogStr + 'TimeStamp_Length: ' + InttoStr(AcpRecebido.TimeStamp_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'TimeStamp_Msg_DataHora: ' + FormatDateTime('yyyy-mm-dd hh:nn:ss',AcpRecebido.TimeStamp_Msg_DataHora) + Char(13) + Char(10);
         LogStr := LogStr + 'Location_IEIdentifier: ' + InttoStr(AcpRecebido.Location_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Location_More_Flag: ' + InttoStr(AcpRecebido.Location_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Location_Length: ' + InttoStr(AcpRecebido.Location_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_RawData_IEIdentifier: ' + InttoStr(AcpRecebido.GPS_Current_RawData_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_RawData_More_Flag: ' + InttoStr(AcpRecebido.GPS_Current_RawData_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_RawData_Length: ' + InttoStr(AcpRecebido.GPS_Current_RawData_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_RawData_Number_Satellites: ' + InttoStr(AcpRecebido.GPS_Current_RawData_Number_Satellites) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Atualizado: ' + InttoStr(AcpRecebido.GPS_Current_Atualizado) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Angulo: ' + InttoStr(AcpRecebido.GPS_Current_Angulo) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_IEIdentifier: ' + InttoStr(AcpRecebido.GPS_Current_Coding_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_More_Flag: ' + InttoStr(AcpRecebido.GPS_Current_Coding_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Length: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Location_Flag1: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Location_Flag1) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Location_Flag2: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Location_Flag2) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_AreaType: ' + InttoStr(AcpRecebido.GPS_Current_Coding_AreaType) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_LocationTypeCoding: ' + InttoStr(AcpRecebido.GPS_Current_Coding_LocationTypeCoding) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Time_Difference: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Time_Difference) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Longitude: ' + FormatFloat('####.0000',AcpRecebido.GPS_Current_Coding_Longitude) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Latitude: ' + FormatFloat('####.0000',AcpRecebido.GPS_Current_Coding_Latitude) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Altitude: ' + FormatFloat('####.0000',AcpRecebido.GPS_Current_Coding_Altitude) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Position_Estimate_Value: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Position_Estimate_Value) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Position_Estimate_Type: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Position_Estimate_Type) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Heading_Estimate_Type: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Heading_Estimate_Type) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Heading_Estimate_Value: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Heading_Estimate_Value) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Distance_Flag: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Distance_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Time_Flag: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Time_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Current_Coding_Velocity: ' + InttoStr(AcpRecebido.GPS_Current_Coding_Velocity) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_RawData_IEIdentifier: ' + InttoStr(AcpRecebido.GPS_Prior_RawData_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_RawData_More_Flag: ' + InttoStr(AcpRecebido.GPS_Prior_RawData_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_RawData_Length: ' + InttoStr(AcpRecebido.GPS_Prior_RawData_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_RawData_Number_Satellites: ' + InttoStr(AcpRecebido.GPS_Prior_RawData_Number_Satellites) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_RawData_Reserved: ' + InttoStr(AcpRecebido.GPS_Prior_RawData_Reserved) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Atualizado: ' + InttoStr(AcpRecebido.GPS_Prior_Atualizado) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Angulo: ' + InttoStr(AcpRecebido.GPS_Prior_Angulo) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_IEIdentifier: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_More_Flag: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Length: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Location_Flag1: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Location_Flag1) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Location_Flag2: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Location_Flag2) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Angulo: ' + InttoStr(AcpRecebido.GPS_Prior_Angulo) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_AreaType: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_AreaType) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_LocationTypeCoding: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_LocationTypeCoding) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Time_Difference: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Time_Difference) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Longitude: ' + FormatFloat('####.0000',AcpRecebido.GPS_Prior_Coding_Longitude) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Latitude: ' + FormatFloat('####.0000',AcpRecebido.GPS_Prior_Coding_Latitude) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Altitude: ' + FormatFloat('####.0000',AcpRecebido.GPS_Prior_Coding_Altitude) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Position_Estimate_Value: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Position_Estimate_Value) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Position_Estimate_Type: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Position_Estimate_Type) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Heading_Estimate_Value: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Heading_Estimate_Value) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Heading_Estimate_Type: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Heading_Estimate_Type) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Distance_Flag: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Distance_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Time_Flag: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Time_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'GPS_Prior_Coding_Velocity: ' + InttoStr(AcpRecebido.GPS_Prior_Coding_Velocity) + Char(13) + Char(10);
         LogStr := LogStr + 'CDRD_WGS84_IEIdentifier: ' + InttoStr(AcpRecebido.CDRD_WGS84_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'CDRD_WGS84_More_Flag: ' + InttoStr(AcpRecebido.CDRD_WGS84_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'CDRD_WGS84_Length: ' + InttoStr(AcpRecebido.CDRD_WGS84_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'CDRD_WGS84_Latitude: ' + InttoStr(AcpRecebido.CDRD_WGS84_Latitude) + Char(13) + Char(10);
         LogStr := LogStr + 'CDRD_WGS84_Longitude: ' + InttoStr(AcpRecebido.CDRD_WGS84_Longitude) + Char(13) + Char(10);
         LogStr := LogStr + 'Area_Delta_IEIdentifier: ' + InttoStr(AcpRecebido.Area_Delta_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Area_Delta_More_Flag: ' + InttoStr(AcpRecebido.Area_Delta_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Area_Delta_Length: ' + InttoStr(AcpRecebido.Area_Delta_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_IEIdentifier: ' + InttoStr(AcpRecebido.Vehicle_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_More_Flag: ' + InttoStr(AcpRecebido.Vehicle_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Length: ' + InttoStr(AcpRecebido.Vehicle_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_Addl_Flag1: ' + InttoStr(AcpRecebido.Vehicle_Flag_Addl_Flag1) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_Language: ' + InttoStr(AcpRecebido.Vehicle_Flag_Language) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_VIN: ' + InttoStr(AcpRecebido.Vehicle_Flag_VIN) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_TCU_Serial: ' + InttoStr(AcpRecebido.Vehicle_Flag_TCU_Serial) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_Vehicle_Color: ' + InttoStr(AcpRecebido.Vehicle_Flag_Vehicle_Color) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_Vehicle_Model: ' + InttoStr(AcpRecebido.Vehicle_Flag_Vehicle_Model) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_License_Plate: ' + InttoStr(AcpRecebido.Vehicle_Flag_License_Plate) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_IMEI: ' + InttoStr(AcpRecebido.Vehicle_Flag_IMEI) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_Addl_Flag2: ' + InttoStr(AcpRecebido.Vehicle_Flag_Addl_Flag2) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_Vehicle_Model_year: ' + InttoStr(AcpRecebido.Vehicle_Flag_Vehicle_Model_year) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_SIMCard_ID: ' + InttoStr(AcpRecebido.Vehicle_Flag_SIMCard_ID) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Flag_Auth_Key: ' + InttoStr(AcpRecebido.Vehicle_Flag_Auth_Key) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Language: ' + AcpRecebido.Vehicle_Language + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_VIN: ' + AcpRecebido.Vehicle_VIN + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_TCU_Serial: ' + InttoStr(AcpRecebido.Vehicle_TCU_Serial) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Vehicle_Color: ' + AcpRecebido.Vehicle_Vehicle_Color + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Vehicle_Model: ' + AcpRecebido.Vehicle_Vehicle_Model + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_License_Plate: ' + AcpRecebido.Vehicle_License_Plate + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_IMEI: ' + AcpRecebido.Vehicle_IMEI + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Vehicle_Model_year: ' + InttoStr(AcpRecebido.Vehicle_Vehicle_Model_year) + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_SIMCard_ID: ' + AcpRecebido.Vehicle_SIMCard_ID + Char(13) + Char(10);
         LogStr := LogStr + 'Vehicle_Auth_Key: ' + AcpRecebido.Vehicle_Auth_Key + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_IEIdentifier: ' + InttoStr(AcpRecebido.BreakDown_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_More_Flag: ' + InttoStr(AcpRecebido.BreakDown_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Length: ' + InttoStr(AcpRecebido.BreakDown_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Breakdown_Flag1: ' + InttoStr(AcpRecebido.BreakDown_Breakdown_Flag1) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Breakdown_Flag2: ' + InttoStr(AcpRecebido.BreakDown_Breakdown_Flag2) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Breakdown_Flag3: ' + InttoStr(AcpRecebido.BreakDown_Breakdown_Flag3) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Breakdown_Flag4: ' + InttoStr(AcpRecebido.BreakDown_Breakdown_Flag4) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Breakdown_Additional: ' + InttoStr(AcpRecebido.BreakDown_Breakdown_Additional) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Breakdown_Sensor: ' + InttoStr(AcpRecebido.BreakDown_Breakdown_Sensor) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Breakdown_Data: ' + AcpRecebido.BreakDown_Breakdown_Data + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Chave: ' + InttoStr(AcpRecebido.BreakDown_Chave) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Bateria_Violada: ' + InttoStr(AcpRecebido.BreakDown_Bateria_Violada) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Bateria_Religada: ' + InttoStr(AcpRecebido.BreakDown_Bateria_Religada) + Char(13) + Char(10);
         LogStr := LogStr + 'BreakDown_Status: ' + InttoStr(AcpRecebido.BreakDown_Status) + Char(13) + Char(10);
         LogStr := LogStr + 'Information_IEIdentifier: ' + InttoStr(AcpRecebido.Information_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Information_More_Flag: ' + InttoStr(AcpRecebido.Information_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Information_Length: ' + InttoStr(AcpRecebido.Information_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Information_Type: ' + InttoStr(AcpRecebido.Information_Type) + Char(13) + Char(10);
         LogStr := LogStr + 'Information_RawData: ' + AcpRecebido.Information_RawData + Char(13) + Char(10);
         LogStr := LogStr + 'Message_More_Flag: ' + InttoStr(AcpRecebido.Message_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Message_TargetApplicationID: ' + InttoStr(AcpRecebido.Message_TargetApplicationID) + Char(13) + Char(10);
         LogStr := LogStr + 'Message_ApplFlag1: ' + InttoStr(AcpRecebido.Message_ApplFlag1) + Char(13) + Char(10);
         LogStr := LogStr + 'Message_ControlFlag1: ' + InttoStr(AcpRecebido.Message_ControlFlag1) + Char(13) + Char(10);
         LogStr := LogStr + 'Message_StatusFlag1: ' + InttoStr(AcpRecebido.Message_StatusFlag1) + Char(13) + Char(10);
         LogStr := LogStr + 'Message_TCUResponseFlag: ' + InttoStr(AcpRecebido.Message_TCUResponseFlag) + Char(13) + Char(10);
         LogStr := LogStr + 'Message_Reserved: ' + InttoStr(AcpRecebido.Message_Reserved) + Char(13) + Char(10);
         LogStr := LogStr + 'Message_Length: ' + InttoStr(AcpRecebido.Message_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Control_Function_IEIdentifier: ' + InttoStr(AcpRecebido.Control_Function_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Control_Function_More_Flag: ' + InttoStr(AcpRecebido.Control_Function_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Control_Function_Length: ' + InttoStr(AcpRecebido.Control_Function_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Control_Function_Entity_ID: ' + InttoStr(AcpRecebido.Control_Function_Entity_ID) + Char(13) + Char(10);
         LogStr := LogStr + 'Control_Function_Reserved: ' + InttoStr(AcpRecebido.Control_Function_Reserved) + Char(13) + Char(10);
         LogStr := LogStr + 'Control_Function_Transmit_Units: ' + InttoStr(AcpRecebido.Control_Function_Transmit_Units) + Char(13) + Char(10);
         LogStr := LogStr + 'Control_Function_Transmit_Interval: ' + InttoStr(AcpRecebido.Control_Function_Transmit_Interval) + Char(13) + Char(10);
         LogStr := LogStr + 'Function_Command_IEIdentifier: ' + InttoStr(AcpRecebido.Function_Command_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Function_Command_More_Flag: ' + InttoStr(AcpRecebido.Function_Command_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Function_Command_Length: ' + InttoStr(AcpRecebido.Function_Command_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Function_Command_Command_or_Status: ' + InttoStr(AcpRecebido.Function_Command_Command_or_Status) + Char(13) + Char(10);
         LogStr := LogStr + 'Function_Command_Raw_Data: ' + AcpRecebido.Function_Command_Raw_Data + Char(13) + Char(10);
         LogStr := LogStr + 'Error_IEIdentifier: ' + InttoStr(AcpRecebido.Error_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'Error_More_Flag: ' + InttoStr(AcpRecebido.Error_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'Error_Length: ' + InttoStr(AcpRecebido.Error_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'Error_Code: ' + InttoStr(AcpRecebido.Error_Code) + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_IEIdentifier: ' + InttoStr(AcpRecebido.DataError_IEIdentifier) + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_More_Flag: ' + InttoStr(AcpRecebido.DataError_More_Flag) + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_Length: ' + InttoStr(AcpRecebido.DataError_Length) + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_Data_Type_MSB: ' + InttoStr(AcpRecebido.DataError_Data_Type_MSB) + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_Data_Type_LSB: ' + InttoStr(AcpRecebido.DataError_Data_Type_LSB) + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_Length_Data_Type: ' + InttoStr(AcpRecebido.DataError_Length_Data_Type) + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_Configuration_Data: ' + AcpRecebido.DataError_Configuration_Data + Char(13) + Char(10);
         LogStr := LogStr + 'DataError_Error_Element: ' + InttoStr(AcpRecebido.DataError_Error_Element) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_IE_Identifier1: ' + InttoStr(AcpRecebido.TCU_Descriptor_IE_Identifier1) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_More_Flag1: ' + InttoStr(AcpRecebido.TCU_Descriptor_More_Flag1) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_Length1: ' + InttoStr(AcpRecebido.TCU_Descriptor_Length1) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_Reserved: ' + InttoStr(AcpRecebido.TCU_Descriptor_Reserved) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_IE_Identifier2: ' + InttoStr(AcpRecebido.TCU_Descriptor_IE_Identifier2) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_More_Flag2: ' + InttoStr(AcpRecebido.TCU_Descriptor_More_Flag2) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_Length2: ' + InttoStr(AcpRecebido.TCU_Descriptor_Length2) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_Device_Id: ' + InttoStr(AcpRecebido.TCU_Descriptor_Device_Id) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_IE_Identifier3: ' + InttoStr(AcpRecebido.TCU_Descriptor_IE_Identifier3) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_More_Flag3: ' + InttoStr(AcpRecebido.TCU_Descriptor_More_Flag3) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_Length3: ' + InttoStr(AcpRecebido.TCU_Descriptor_Length3) + Char(13) + Char(10);
         LogStr := LogStr + 'TCU_Descriptor_Version_Id: ' + InttoStr(AcpRecebido.TCU_Descriptor_Version_Id) + Char(13) + Char(10);

         SalvaLog(Arq_Log, LogStr );

      End;

   Except

      Begin
         SalvaLog(Arq_Log, 'Não decodificou (2): ' + PacketStr);
         SetLength(PacketTot, 0);
         Result := 0;
         AcpRecebido.Header_Ok := False;
      End;
   End;

End;

// Single Error Element
Function gravacao_acp245.Decode_App02_03(Var PosInicio: Word): Word;

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

      // Version
      PosInicio := Decode_Version(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Version - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Reserved
      PosInicio := Decode_Reserved(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Reserved - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Message Fields
      PosInicio := Decode_Message(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Message - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Error Element
      PosInicio := Decode_Error(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Error - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Vehicle Descriptor Element
      PosInicio := Decode_Vehicle(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Vehicle - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      Result := PosInicio;
   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App02_03): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpRecebido.Header_Ok := False;
   End;
End;

// Multiple Error Element
Function gravacao_acp245.Decode_App02_09(Var PosInicio: Word): Word;

Begin
   Try

      // Version
      PosInicio := Decode_Version(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Version - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Message Fields
      PosInicio := Decode_Message(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Message - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Error Element
      PosInicio := Decode_TCU_Data_Error(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_TCU_Data_Error - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Vehicle Descriptor Element
      PosInicio := Decode_Vehicle(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Vehicle - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      Result := PosInicio;
   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App02_09): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpRecebido.Header_Ok := False;
   End;
End;

Function gravacao_acp245.Decode_App06(Var PosInicio: Word): Word;

Begin

   Try

      // Version
      PosInicio := Decode_Version(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Version - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Control Function
      PosInicio := Decode_Control_Function(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Control_Function - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Function Command
      PosInicio := Decode_Function_Command(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Function_Command - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Error Element
      PosInicio := Decode_Error(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Error - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Vehicle
      PosInicio := Decode_Vehicle(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Vehicle - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      Result := PosInicio;
   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App06): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpRecebido.Header_Ok := False;
   End;
End;

Function gravacao_acp245.Decode_App10(Var PosInicio: Word): Word;

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

      // Version
      PosInicio := Decode_Version(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Version - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // TimeStamp Element 4 Bytes
      PosInicio := Decode_TimeStamp(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_TimeStamp - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // TimeStamp Element 4 Bytes
      PosInicio := Decode_Location(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Location - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Vehicle
      PosInicio := Decode_Vehicle(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Vehicle - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // BreakDown
      PosInicio := Decode_BreakDown(PosInicio, 10);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_BreakDown - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      //Rever - Falta o Information Type
      Result := PosInicio;

   Except
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App10): ' + PacketStr);
      SetLength(PacketTot, 0);
      Result := 0;
      AcpRecebido.Header_Ok := False;
   End;
End;

Function gravacao_acp245.Decode_App11(Var PosInicio: Word): Word;

Begin
   Try


      // Version Element 5 Bytes
      PosInicio := Decode_Version(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Version - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // TimeStamp Element 4 Bytes
      PosInicio := Decode_TimeStamp(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_TimeStamp - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // TimeStamp Element 24 Bytes (media)
      PosInicio := Decode_Location(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Location - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Vehicle Element 18 bytes (media)
      PosInicio := Decode_Vehicle(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_Vehicle - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // BreakDown
      PosInicio := Decode_BreakDown(PosInicio, 11);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_BreakDown - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      Result := PosInicio;
   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Não decodificou (Decode_App11): ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;



Function gravacao_acp245.Decode_Version(Var PosInicio: Word): Word;
Var
   StrBits: String;


Begin
   Try

      PosLimite := PosInicio+1;

      // Header do Version
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      AcpRecebido.Version_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Version_more_Flag    := StrtoInt(StrBits[3]);
      AcpRecebido.Version_Length       := BintoInt(Copy(StrBits, 4, 5));
      PosLimite := PosLimite + AcpRecebido.Version_Length;

      if AcpRecebido.Version_Length > 0 then
      Begin
         // Version dados

         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, AcpRecebido.Version_Length);
         AcpRecebido.Version_Car_Manufacturer := BintoInt(Copy(StrBits, 1, 8));
         AcpRecebido.Version_TCU_Manufacturer := BintoInt(Copy(StrBits, 9, 8));
         AcpRecebido.Version_Major_Hardware_Release := BintoInt(Copy(StrBits, 17, 8));
         AcpRecebido.Version_Major_Software_Release := BintoInt(Copy(StrBits, 25, 8));
      End;

      if (AcpRecebido.Version_TCU_Manufacturer = 0) then
      Begin
         Result := 0;
         SalvaLog(Arq_Log, 'TCU_Manufacturer Inválido: ' + PacketStr);
      End
      Else
         Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Version - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 2;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Version: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;



Function gravacao_acp245.Decode_TimeStamp(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin
   Try

      PosLimite := PosInicio+4;

      // Header de TimeStamp Element 4 Bytes
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 4);
      AcpRecebido.TimeStamp_Length := 4;
      Try
         AcpRecebido.TimeStamp_Msg_DataHora :=
            EncodeDateTime(1990 + BintoInt(Copy(StrBits, 1, 6)), // Ano
            BintoInt(Copy(StrBits, 7, 4)), // Mes
            BintoInt(Copy(StrBits, 11, 5)), // Dia
            BintoInt(Copy(StrBits, 16, 5)), // Hora
            BintoInt(Copy(StrBits, 21, 6)), // Minuto
            BintoInt(Copy(StrBits, 27, 6)), // Segundo
            0); // Milisegundos

      Except

      End;

      Result  := PosInicio;
      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_TimeStamp - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 3;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_TimeStamp: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_Location(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin


   Try

      PosLimite := PosInicio+1;
      PosTotal  := PosLimite;

      // Header de Location element
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      AcpRecebido.Location_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Location_more_Flag    := StrtoInt(StrBits[3]);
      AcpRecebido.Location_Length       := BintoInt(Copy(StrBits, 4, 5));

      PosTotal                          := PosTotal + AcpRecebido.Location_Length ;

      if AcpRecebido.Location_more_Flag = 1 then
      Begin
         PosLimite := PosLimite + 1;
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,  1);
         AcpRecebido.Location_Length := BintoInt(Copy(StrBits, 4, 5));
      End;

      PosInicio := Decode_GPSRawData_Current(PosInicio);
      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_GPSRawData_Current - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      if PosInicio < PosTotal then
         PosInicio := Decode_GPSRawData_Prior(PosInicio);

      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_GPSRawData_Prior - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

      // Current Dead Reckoning Data AcpCDRD_WGS84
      if PosInicio < PosTotal then
         PosInicio := Decode_CDRD_WGS84(PosInicio);

      If debug >= 5 Then
         SalvaLog(Arq_Log, 'Decode_CDRD_WGS84 - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));


      // Array of Area Location Delta Coding
      if PosInicio < PosTotal then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosTotal, 1);
         AcpRecebido.Area_Delta_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpRecebido.Area_Delta_more_Flag    := StrtoInt(StrBits[3]);
         AcpRecebido.Area_Delta_Length       := BintoInt(Copy(StrBits, 4, 5));
         PosLimite := PosLimite + AcpRecebido.Area_Delta_Length;
      End;

      if (PosInicio > PosLimite) then
      Begin
         PosInicio := PosTotal;
         SalvaLog(Arq_Log,
            'Decode_Location - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
      End;

      Result := PosInicio;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Location: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;


Function gravacao_acp245.Decode_GPSRawData_Current(Var PosInicio: Word): Word;
Var
   StrBits: String;
   Contsat: Integer;
Begin


   Try

      PosLimite := PosInicio+1;

      // GPSRawData - Current Element
      if (AcpRecebido.Location_Length > 0) Then
      Begin

        // Current GPSRawData Element
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.GPS_Current_RawData_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpRecebido.GPS_Current_RawData_More_Flag    := StrtoInt(StrBits[3]);
         AcpRecebido.GPS_Current_RawData_Length       := BintoInt(Copy(StrBits, 4, 5));
      End;

      // GPSRawData - Current Element
      if (AcpRecebido.GPS_Current_RawData_Length > 0) Then
      Begin

         //Current
         PosInicio := Decode_Area_Location_Coding_Current(PosInicio);
         If debug >= 5 Then
            SalvaLog(Arq_Log, 'Decode_Area_Location_Coding_Current - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

         //Current GPSRawData Current Element - Number Satelites
         PosLimite := PosLimite +1;
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosTotal, 1);
         AcpRecebido.GPS_Current_RawData_Number_Satellites := BintoInt(Copy(StrBits, 1, 4));
         AcpRecebido.GPS_Current_RawData_Reserved          := BintoInt(Copy(StrBits, 5, 4));

         if  AcpRecebido.GPS_Current_RawData_Number_Satellites > 0 then
            For Contsat := 1 to  AcpRecebido.GPS_Current_RawData_Number_Satellites Do
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosTotal, 1);

      End;

      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         PosInicio := PosTotal;
         SalvaLog(Arq_Log,
            'Decode_GPSRawData_Current - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_GPSRawData_Current: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_GPSRawData_Prior(Var PosInicio: Word): Word;
Var
   StrBits: String;
   Contsat: Integer;
Begin

   Try

      PosLimite := PosInicio+1;

      // GPSRawData - Prior Element
      if (AcpRecebido.Location_Length > 0) Then
      Begin

        // Prior GPSRawData Element
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.GPS_Prior_RawData_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpRecebido.GPS_Prior_RawData_More_Flag    := StrtoInt(StrBits[3]);
         AcpRecebido.GPS_Prior_RawData_Length       := BintoInt(Copy(StrBits, 4, 5));

      End;

      // GPSRawData - Prior Element
      if (AcpRecebido.GPS_Prior_RawData_Length > 0) and (PosInicio < PosTotal) Then
      Begin

         //Prior
         PosInicio := Decode_Area_Location_Coding_Prior(PosInicio);
         If debug >= 5 Then
            SalvaLog(Arq_Log, 'Decode_Area_Location_Coding_Prior - PosInicio: '+ inttoStr(PosInicio) + ' PosLimite: ' + InttoStr(PosLimite));

         //Current GPSRawData Prior Element - Number Satelites
         PosLimite := PosLimite + 1;
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosTotal, 1);
         AcpRecebido.GPS_Prior_RawData_Number_Satellites := BintoInt(Copy(StrBits, 1, 4));
         AcpRecebido.GPS_Prior_RawData_Reserved          := BintoInt(Copy(StrBits, 5, 4));

         PosLimite := PosLimite +  AcpRecebido.GPS_Prior_RawData_Reserved;

         if  AcpRecebido.GPS_Prior_RawData_Number_Satellites > 0 then
            For Contsat := 1 to  AcpRecebido.GPS_Prior_RawData_Number_Satellites Do
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosTotal, 1);

      End;

      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         PosInicio := PosTotal;
         SalvaLog(Arq_Log,
            'Decode_GPSRawData_Prior - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_GPSRawData_Prior: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_Area_Location_Coding_Current(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin



   Try

      PosLimite := PosInicio+1;

      // GPSRawData Element Area Location Coding
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      AcpRecebido.GPS_Current_Coding_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.GPS_Current_Coding_more_Flag    := StrtoInt(StrBits[3]);
      AcpRecebido.GPS_Current_Coding_Length       := BintoInt(Copy(StrBits, 4, 5));

      if (AcpRecebido.GPS_Current_Coding_Length > 0) then
      Begin

         // 1 byte
         PosLimite := PosLimite + AcpRecebido.GPS_Current_Coding_Length;
         StrBits   := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Current_Coding_More_Flag1              :=  BintoInt(Copy(StrBits, 1, 1));
         AcpRecebido.GPS_Current_Coding_Location_Flag1          :=  BintoInt(Copy(StrBits, 2, 7));

         //Trata Atualizado isoladamente
         if Copy(StrBits,5,1) = '1' then
            AcpRecebido.GPS_Current_Atualizado := 0
         Else
            AcpRecebido.GPS_Current_Atualizado := 1;

         if AcpRecebido.GPS_Current_Coding_More_Flag1 = 1 then
         Begin
            //  2 byte
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
            AcpRecebido.GPS_Current_Coding_More_Flag2              := BintoInt(Copy(StrBits, 1, 1));
            AcpRecebido.GPS_Current_Coding_Location_Flag2          := BintoInt(Copy(StrBits, 2, 7));
         End;

         // 3 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Current_Coding_areatype                := BintoInt(Copy(StrBits, 1, 3));
         AcpRecebido.GPS_Current_Coding_locationtypecoding      := BintoInt(Copy(StrBits, 4, 3));
         AcpRecebido.GPS_Current_Coding_Reserved                := BintoInt(Copy(StrBits, 4, 3));

         // 4 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Current_Coding_More_Flag3              := BintoInt(Copy(StrBits, 1, 1));
         AcpRecebido.GPS_Current_Coding_time_difference         := BintoInt(Copy(StrBits, 2, 7));

         // 5,6,7,8 bytes
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,4);
         AcpRecebido.GPS_Current_Coding_Longitude               := CompTwoToLatLong(Copy(StrBits, 1, 32));

         // 9,10,11,12 bytes
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,4);
         AcpRecebido.GPS_Current_Coding_Latitude                := CompTwoToLatLong(Copy(StrBits, 1, 32));

         // 13,14 bytes
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,2);
         AcpRecebido.GPS_Current_Coding_altitude                := BintoInt(Copy(StrBits, 1, 16));

         // 15 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Current_Coding_Position_estimate_value := BintoInt(Copy(StrBits, 1, 7));
         AcpRecebido.GPS_Current_Coding_Position_estimate_type  := BintoInt(Copy(StrBits, 8, 1));

         // 16 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Current_Coding_heading_estimate_Type   := BintoInt(Copy(StrBits, 1, 3));
         AcpRecebido.GPS_Current_Coding_heading_estimate_value  := BintoInt(Copy(StrBits, 4, 5));

         // 17 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Current_Coding_Reserved2               := BintoInt(Copy(StrBits, 1, 4));
         AcpRecebido.GPS_Current_Coding_distance_Flag           := BintoInt(Copy(StrBits, 5, 2));
         AcpRecebido.GPS_Current_Coding_time_Flag               := BintoInt(Copy(StrBits, 7, 2));

         // 1 byte  -136
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Current_Coding_Velocity                := BintoInt(Copy(StrBits, 1, 8));

         //Trata  Angulo isoladamente
         AcpRecebido.GPS_Current_Angulo                         := BintoInt(Copy(StrBits, 6, 3)) * 45;

      End;

      if (PosInicio > PosLimite) then
      Begin
         PosInicio := PosTotal;
         SalvaLog(Arq_Log,
            'Decode_Area_Location_Coding_Current - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 4;
      End;

      Result := PosInicio;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Area_Location_Coding_Current: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;


Function gravacao_acp245.Decode_Area_Location_Coding_Prior(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin

   Try

      PosLimite := PosInicio+1;

      // GPSRawData Element Area Location Coding
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      AcpRecebido.GPS_Prior_Coding_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.GPS_Prior_Coding_more_Flag    := StrtoInt(StrBits[3]);
      AcpRecebido.GPS_Prior_Coding_Length       := BintoInt(Copy(StrBits, 4, 5));

      if (AcpRecebido.GPS_Prior_Coding_Length > 0) and (PosInicio < PosTotal) then
      Begin

         // 1 byte
         PosLimite := PosLimite +  AcpRecebido.GPS_Prior_Coding_Length;
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_More_Flag1              :=  BintoInt(Copy(StrBits, 1, 1));
         AcpRecebido.GPS_Prior_Coding_Location_Flag1          :=  BintoInt(Copy(StrBits, 2, 7));

         // 2 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_More_Flag2              := BintoInt(Copy(StrBits, 1, 1));
         AcpRecebido.GPS_Prior_Coding_Location_Flag2          := BintoInt(Copy(StrBits, 2, 7));

         // 3 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_areatype                := BintoInt(Copy(StrBits, 1, 3));
         AcpRecebido.GPS_Prior_Coding_locationtypecoding      := BintoInt(Copy(StrBits, 4, 3));
         AcpRecebido.GPS_Prior_Coding_Reserved                := BintoInt(Copy(StrBits, 4, 3));

         // 4 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_More_Flag3              := BintoInt(Copy(StrBits, 1, 1));
         AcpRecebido.GPS_Prior_Coding_time_difference         := BintoInt(Copy(StrBits, 2, 7));

         // 5,6,7,8 bytes
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,4);
         AcpRecebido.GPS_Prior_Coding_Longitude               := CompTwoToLatLong(Copy(StrBits, 1, 32));

         // 9,10,11,12 bytes
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,4);
         AcpRecebido.GPS_Prior_Coding_Latitude                := CompTwoToLatLong(Copy(StrBits, 1, 32));

         // 13,14 bytes
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,2);
         AcpRecebido.GPS_Prior_Coding_altitude                := BintoInt(Copy(StrBits, 1, 16));

         // 15 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_Position_estimate_value := BintoInt(Copy(StrBits, 1, 7));
         AcpRecebido.GPS_Prior_Coding_Position_estimate_type  := BintoInt(Copy(StrBits, 8, 1));

         // 16 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_heading_estimate_Type   := BintoInt(Copy(StrBits, 1, 3));
         AcpRecebido.GPS_Prior_Coding_heading_estimate_value  := BintoInt(Copy(StrBits, 4, 5));

         // 17 byte
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_Reserved2               := BintoInt(Copy(StrBits, 1, 4));
         AcpRecebido.GPS_Prior_Coding_distance_Flag           := BintoInt(Copy(StrBits, 5, 2));
         AcpRecebido.GPS_Prior_Coding_time_Flag               := BintoInt(Copy(StrBits, 7, 2));

         // 1 byte  -136
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,1);
         AcpRecebido.GPS_Prior_Coding_Velocity                := BintoInt(Copy(StrBits, 1, 8));

         //Trata Atualizado isoladamente
         if (AcpRecebido.GPS_Prior_Coding_Location_Flag1 = 1) then
            AcpRecebido.GPS_Prior_Atualizado := 0
         Else
            AcpRecebido.GPS_Prior_Atualizado := 1;

         //Trata  Angulo isoladamente
         AcpRecebido.GPS_Prior_Angulo                         := BintoInt(Copy(StrBits, 6, 3)) * 45;

      End;

      if (PosInicio > PosLimite) then
      Begin
         PosInicio := PosTotal;
         SalvaLog(Arq_Log,
            'Decode_Area_Location_Coding_Prior - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
      End;

      Result := PosInicio;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Area_Location_Coding_Prior: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;


Function gravacao_acp245.Decode_CDRD_WGS84(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin



   Try

      PosLimite := PosInicio+1;

      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);

      AcpRecebido.CDRD_WGS84_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.CDRD_WGS84_more_Flag := StrtoInt(StrBits[3]);
      AcpRecebido.CDRD_WGS84_Length := BintoInt(Copy(StrBits, 4, 5));

      PosLimite :=  PosLimite + AcpRecebido.CDRD_WGS84_Length;
      if (AcpRecebido.CDRD_WGS84_Length = 2) and (PosInicio < PosTotal)  Then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.CDRD_WGS84_Latitude := BintoInt(Copy(StrBits, 1, 8));
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.CDRD_WGS84_Longitude := BintoInt(Copy(StrBits, 1, 8));
      End;

      if (PosInicio > PosLimite) then
      Begin
         PosInicio := PosTotal;
         SalvaLog(Arq_Log,
            'Decode_CDRD_WGS84 - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 4;
      End;

      Result := PosInicio;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_CDRD_WGS84: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_Area_Location_Delta(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin

   Try

      PosLimite := PosInicio+1;
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);

      AcpRecebido.Area_Delta_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Area_Delta_More_Flag    := StrtoInt(StrBits[3]);
      AcpRecebido.Area_Delta_Length       := BintoInt(Copy(StrBits, 4, 5));

      PosLimite :=  PosLimite + AcpRecebido.Area_Delta_Length;

      if AcpRecebido.Area_Delta_Length > 0  Then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, AcpRecebido.Area_Delta_Length);
      End;

      if (PosInicio > PosLimite) then
      Begin
         PosInicio := PosTotal;
         SalvaLog(Arq_Log,
            'Decode_Area_Location_Delta - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 4;
      End;

      Result := PosInicio;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Area_Location_Delta: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_Vehicle(Var PosInicio: Word): Word;
Var
   StrBits: String;
   TmpBytes: Word;
   IEIdentifier: byte; // Para os parametros Opcionais
   more_Flag: byte; // Para os parametros Opcionais
   Tamanho: byte; // Para os parametros Opcionais

Begin

   Try

      PosLimite := PosInicio+1;

      // Header do Vehicle
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      AcpRecebido.Vehicle_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Vehicle_more_Flag := StrtoInt(StrBits[3]);
      AcpRecebido.Vehicle_Length := BintoInt(Copy(StrBits, 4, 5));

      PosLimite := PosLimite + AcpRecebido.Vehicle_Length;

      // Tem pelo menos os flags do vehicle
      if AcpRecebido.Vehicle_Length >= 2 Then
      Begin
         PosLimite := PosLimite + AcpRecebido.Vehicle_Length;

         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 2);
         // Vehicle Flag 1
         AcpRecebido.Vehicle_Flag_Addl_Flag1 := BintoInt(StrBits[1]);
         AcpRecebido.Vehicle_Flag_Language := BintoInt(StrBits[2]);
         AcpRecebido.Vehicle_Flag_VIN := BintoInt(StrBits[3]);
         AcpRecebido.Vehicle_Flag_TCU_Serial := BintoInt(StrBits[4]);
         AcpRecebido.Vehicle_Flag_Vehicle_Color := BintoInt(StrBits[5]);
         AcpRecebido.Vehicle_Flag_Vehicle_Model := BintoInt(StrBits[6]);
         AcpRecebido.Vehicle_Flag_License_Plate := BintoInt(StrBits[7]);
         AcpRecebido.Vehicle_Flag_IMEI := BintoInt(StrBits[8]);
         // Vehicle Flag 2
         AcpRecebido.Vehicle_Flag_Addl_Flag2 := BintoInt(StrBits[9]);
         AcpRecebido.Vehicle_Flag_Vehicle_Model_year := BintoInt(StrBits[10]);
         AcpRecebido.Vehicle_Flag_SIMCard_ID := BintoInt(StrBits[11]);
         AcpRecebido.Vehicle_Flag_Auth_Key := BintoInt(StrBits[12]);

      End;

      // Language
      if AcpRecebido.Vehicle_Flag_Language = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_Language := InttoStr(BintoInt(StrBits));
         End;
      End;

      // Model year
      if AcpRecebido.Vehicle_Flag_Vehicle_Model_year = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_Vehicle_Model_year := BintoInt(StrBits);
         End;
      End;

      // VIN
      if AcpRecebido.Vehicle_Flag_VIN = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            // Mudar: aki é texto
            AcpRecebido.Vehicle_VIN := InttoStr(BintoInt(StrBits));
         End;
      End;

      // TCU serial
      if AcpRecebido.Vehicle_Flag_TCU_Serial = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_TCU_Serial := BintoInt(StrBits);
         End;
      End;

      // License Plate
      if AcpRecebido.Vehicle_Flag_License_Plate = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_License_Plate := InttoStr(BintoInt(StrBits));
         End;
      End;

      // Vehicle Color
      if AcpRecebido.Vehicle_Flag_Vehicle_Color = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_Vehicle_Color := InttoStr(BintoInt(StrBits));
         End;
      End;

      // Vehicle Model
      if AcpRecebido.Vehicle_Flag_Vehicle_Model = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_Vehicle_Model := InttoStr(BintoInt(StrBits));
         End;
      End;

      // IMEI
      if AcpRecebido.Vehicle_Flag_IMEI = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_IMEI := BCDtoString(StrBits);
         End;
      End;

      // SIM Card ID
      if AcpRecebido.Vehicle_Flag_SIMCard_ID = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_SIMCard_ID := Trim(BCDtoString(StrBits));
         End;
      End;

      // Auth. Key
      if AcpRecebido.Vehicle_Flag_Auth_Key = 1 then
      Begin
         // Le o header do proximo parametro para saber o tamanho
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Tamanho := BintoInt(Copy(StrBits, 4, 5));
         if Tamanho > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Tamanho);
            AcpRecebido.Vehicle_Auth_Key := InttoStr(BintoInt(StrBits));
         End;
      End;

      if (Length(AcpRecebido.Vehicle_SIMCard_ID) <> 20) or (AcpRecebido.Vehicle_SIMCard_ID = '')
         or (Copy(AcpRecebido.Vehicle_SIMCard_ID, 1, 2) <> '89') then
      Begin
         SalvaLog(Arq_Log, 'ID Invalido: ' + AcpRecebido.Vehicle_SIMCard_ID);
         AcpRecebido.Header_Ok := False;
      End;

      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Vehicle - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 5;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Vehicle: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_BreakDown(Var PosInicio: Word;
   pTipo_App: Integer): Word;
Var
   StrBits: String;
   // TmpBytes      : Word;
   Contador: Word;
   IEIdentifier: byte; // Para os parametros Opcionais
   more_Flag: byte; // Para os parametros Opcionais
   Length: byte; // Para os parametros Opcionais

Begin

   Try

      PosLimite := PosInicio+1;

      // Header BreakDown
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      AcpRecebido.BreakDown_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.BreakDown_more_Flag := StrtoInt(StrBits[3]);
      AcpRecebido.BreakDown_Length := BintoInt(Copy(StrBits, 4, 5));

      PosLimite := PosLimite + AcpRecebido.BreakDown_Length;

      if AcpRecebido.BreakDown_Length > 1 then
      Begin

         // BreakDown Flag1 - Obrigatorio
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.BreakDown_Breakdown_Flag1 := BintoInt(StrBits);

         if (pTipo_App = 11) and (Debug in [9]) then
            SalvaLog(Arq_Log, 'BreakDown Flag1: ' + StrBits);

         // BreakDown Flag2 - Obrigatorio
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.BreakDown_Breakdown_Flag2 := BintoInt(StrBits);
         if (pTipo_App = 11) and (Debug in [9]) then
            SalvaLog(Arq_Log, 'BreakDown Flag2: ' + StrBits);

         if Copy(StrBits, 2, 1) = '1' then
            AcpRecebido.BreakDown_Chave := 1
         Else
            AcpRecebido.BreakDown_Chave := 0;

         // Se more Flag = 1
         if StrBits[1] = '1' then
         Begin
            // BreakDown Flag3
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
            AcpRecebido.BreakDown_Breakdown_Flag3 := BintoInt(StrBits);
            if (pTipo_App = 11) and (Debug in [9]) then
               SalvaLog(Arq_Log, 'BreakDown Flag3: ' + StrBits);

            if StrBits[4] = '1' then // Main battery is reconnected
               AcpRecebido.BreakDown_Bateria_Religada := 1;
            if StrBits[5] = '1' then
               AcpRecebido.BreakDown_Bateria_Violada := 1;

            // More flag = 1 means that there is additional breakdown sources flags defined by TCU suppliers.
            if StrBits[1] = '1' then
            Begin
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
               AcpRecebido.BreakDown_Breakdown_Flag4 := BintoInt(StrBits);
            End;

         End;

         // BreakDown Sensor
         // When Breakdown sensor bit 7 is set to 1, the format of breakdown data field is the same as described in item 3.9.1 and represents breakdown source status
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.BreakDown_Breakdown_sensor := BintoInt(StrBits);
         AcpRecebido.BreakDown_Status := BintoInt(StrBits[8]);

         // Header BreakDown Data
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Length := BintoInt(Copy(StrBits, 4, 5));

         // Quando nao for app_id = 11 Alarme Entao os flags estao no Status
         if (AcpRecebido.BreakDown_Status = 1) and (Length >= 1) then
         Begin

            // BreakDown Flag1
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
            AcpRecebido.BreakDown_Breakdown_Flag1 := BintoInt(StrBits);
            if Debug in [9] then
               SalvaLog(Arq_Log, 'BreakDown Flag1: ' + StrBits);

            if (Length >= 2) then
            Begin
               // BreakDown Flag2
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
               AcpRecebido.BreakDown_Breakdown_Flag2 := BintoInt(StrBits);
               if Debug in [9] then
                  SalvaLog(Arq_Log, 'BreakDown Flag2: ' + StrBits);

               if StrBits[2] = '1' then
                  AcpRecebido.BreakDown_Chave := 1
               Else
                  AcpRecebido.BreakDown_Chave := 0;
            End;

            if (Length >= 3) then
            Begin
               // BreakDown Flag3
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
               AcpRecebido.BreakDown_Breakdown_Flag3 := BintoInt(StrBits);
               if Debug in [9] then
                  SalvaLog(Arq_Log, 'BreakDown Flag3: ' + StrBits);

               if StrBits[4] = '1' then // Main battery is reconnected
                  AcpRecebido.BreakDown_Bateria_Religada := 1;
               if StrBits[5] = '1' then
                  AcpRecebido.BreakDown_Bateria_Violada := 1;
            End;

            if (Length >= 4) then
            Begin
               // More flag = 1 means that there is additional breakdown sources flags defined by TCU suppliers.
               Begin
                  StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
                  AcpRecebido.BreakDown_Breakdown_Flag3 := BintoInt(StrBits);
               End;
            End;

            // More flag = 1 means that there is additional breakdown sources flags defined by TCU suppliers.
            if StrBits[1] = '1' then
            Begin
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
               AcpRecebido.BreakDown_Breakdown_Flag4 := BintoInt(StrBits);
            End;

         End
         Else if Length >= 1 then
         Begin

            for Contador := 1 to Length do
            Begin
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Length);
               AcpRecebido.BreakDown_Breakdown_Data := AcpRecebido.BreakDown_Breakdown_Data +
                  IntToHex(BintoInt(Copy(StrBits, 4, 5)), 2);
            End;

            if Debug in [9] then
               SalvaLog(Arq_Log, 'BreakDown Data: ' +
                  AcpRecebido.BreakDown_Breakdown_Data);
         End;

      End;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_BreakDown - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;

      Result := PosInicio;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_BreakDown: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_Information(Var PosInicio: Word): Word;
Var
   StrBits: String;
//   TmpBytes: Word;
   Contador: Word;
   IEIdentifier: byte; // Para os parametros Opcionais
   more_Flag: byte; // Para os parametros Opcionais
   Length: byte; // Para os parametros Opcionais
Begin

   Try

       PosLimite := PosInicio+1;

      // Header Information
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      AcpRecebido.Information_IEIdentifier   := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Information_more_Flag      := StrtoInt(StrBits[3]);
      AcpRecebido.Information_Length         := BintoInt(Copy(StrBits, 4, 5));

      PosLimite := PosLimite + AcpRecebido.Information_Length;

      if AcpRecebido.Information_Length > 0 then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.Information_Type := BintoInt(Copy(StrBits, 2, 7));

         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         more_Flag := StrtoInt(StrBits[3]);
         Length := BintoInt(Copy(StrBits, 4, 5));

         if Length >= 1 then
            for Contador := 1 to Length do
            Begin
               StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, Length);
               AcpRecebido.Information_RawData :=
                  AcpRecebido.Information_RawData +
                  IntToHex(BintoInt(Copy(StrBits, 4, 5)), 2);
            End;

      End;
      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Information - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Information: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_Message(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin

   Try

      PosLimite := PosInicio+3;
      // MessageFields
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 3);

      AcpRecebido.Message_more_Flag           := BintoInt(StrBits[1]);
      AcpRecebido.Message_TargetApplicationID := BintoInt(Copy(StrBits, 2, 7));
      AcpRecebido.Message_ApplFlag1           := BintoInt(Copy(StrBits, 9, 2));
      AcpRecebido.Message_ControlFlag1        := BintoInt(Copy(StrBits, 11, 6));
      AcpRecebido.Message_StatusFlag1         := BintoInt(Copy(StrBits, 17, 2));;
      AcpRecebido.Message_TCUResponseFlag     := BintoInt(Copy(StrBits, 19, 2));
      AcpRecebido.Message_Reserved            := BintoInt(Copy(StrBits, 21, 4));
      AcpRecebido.Message_Length              := 3;
      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Message - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Message: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;

Function gravacao_acp245.Decode_Control_Function(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin

   Try
      // MessageFields
      PosLimite := PosInicio+1;

      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);

      AcpRecebido.Control_Function_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Control_Function_more_Flag := StrtoInt(StrBits[3]);
      AcpRecebido.Control_Function_Length := BintoInt(Copy(StrBits, 4, 5));

      PosLimite := PosLimite + AcpRecebido.Control_Function_Length;

      if AcpRecebido.Control_Function_Length >= 1 then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.Control_Function_Entity_ID := BintoInt(Copy(StrBits, 1, 8));
      End;

      if AcpRecebido.Control_Function_Length >= 3 then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 2);
         AcpRecebido.Control_Function_Reserved := BintoInt(Copy(StrBits, 1, 4));
         AcpRecebido.Control_Function_Transmit_Units := BintoInt(Copy(StrBits, 5, 4));
         AcpRecebido.Control_Function_Transmit_Interval :=
            BintoInt(Copy(StrBits, 9, 8));;
      End;

      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Control - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;


   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Control: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;

Function gravacao_acp245.Decode_Function_Command(Var PosInicio: Word): Word;
Var
   StrBits: String;
   Contador: Word;
//   IEIdentifier: byte; // Para os parametros RawData
//   more_Flag: byte; // Para os parametros RawData
//   Length: byte; // Para os parametros RawData

Begin
   Try

      PosLimite := PosInicio+1;

      // MessageFields
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 2);

      AcpRecebido.Function_Command_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Function_Command_more_Flag := StrtoInt(StrBits[3]);
      AcpRecebido.Function_Command_Length := BintoInt(Copy(StrBits, 4, 5));
      AcpRecebido.Function_Command_Command_or_Status := BintoInt(Copy(StrBits, 9, 8));

      PosLimite := PosLimite + AcpRecebido.Function_Command_Length;

      // Raw Data
      if AcpRecebido.Function_Command_Length > 1 then
      Begin

         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.Function_Command_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
         AcpRecebido.Function_Command_more_Flag := BintoInt(Copy(StrBits, 4, 5));
         AcpRecebido.Function_Command_Length := BintoInt(Copy(StrBits, 4, 5));
         if AcpRecebido.Function_Command_Length > 0 then
         Begin
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite,
               AcpRecebido.Function_Command_Length);

            for Contador := 1 to AcpRecebido.Function_Command_Length do
               AcpRecebido.Function_Command_Raw_Data := AcpRecebido.Function_Command_Raw_Data +
                  StrBits[Contador] + ':';
         End;

      End;
      Result := PosInicio;
      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Function_Command - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;
   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Function_Command: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;

Function gravacao_acp245.Decode_Error(Var PosInicio: Word): Word;
Var
   StrBits: String;

Begin

   Try

      PosLimite := PosInicio+1;

      // MessageFields
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);

      AcpRecebido.Error_IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.Error_more_Flag    := StrtoInt(StrBits[3]);
      AcpRecebido.Error_Length       := BintoInt(Copy(StrBits, 4, 5));

      PosLimite := PosLimite + AcpRecebido.Error_Length;

      if AcpRecebido.Error_Length >= 1 then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.Error_Code := BintoInt(StrBits);
      End;

      if AcpRecebido.Error_Length > 1 then
      Begin
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, AcpRecebido.Error_Length - 1);
      End;

      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Error - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Error: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;

End;

Function gravacao_acp245.Decode_TCU_Data_Error(Var PosInicio: Word): Word;
Var
   StrBits: String;
   BytesTotal: Word;
   BytesLidos: Word;
   BytesRetorno: Word;
   Contador: Word;
   NumElementos: Word;
Begin

   Try

      PosLimite := PosInicio+1;

      // TCU_Data_Error
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      BytesLidos := 1;
      NumElementos := 1;
      SetLength(AcpDataError, NumElementos);

      AcpDataError[0].IEIdentifier := BintoInt(Copy(StrBits, 1, 2));
      AcpDataError[0].more_Flag := StrtoInt(StrBits[3]);
      AcpDataError[0].Length := BintoInt(Copy(StrBits, 4, 5));
      PosLimite := PosLimite + AcpDataError[0].Length;

      BytesTotal := BintoInt(Copy(StrBits, 4, 5));

      SalvaLog(Arq_Log, 'Decode_TCU_Data_Error Length: ' +
         InttoStr(BytesTotal));

      while BytesLidos < BytesTotal do
      Begin

         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 3);
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
            StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
            AcpDataError[NumElementos - 1].Configuration_Data :=
               AcpDataError[NumElementos - 1].Configuration_Data +
               IntToHex(BintoInt(Copy(StrBits, 1, 8)), 2);
         End;
         // Soma os bytes do parametro
         BytesLidos := BytesLidos + BytesRetorno;

         // Le o error Element
         StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
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

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_TCU_Data_Error - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;

      Result := PosInicio;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_TCU_Data_Error: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;

Function gravacao_acp245.Decode_TCU_Descriptor(Var PosInicio: Word): Word;

Var
   StrBits: String;

Begin


   Try

      PosLimite := PosInicio+1;

      // TCU_Descriptor
      StrBits    := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);

      AcpRecebido.TCU_Descriptor_IE_Identifier1 := BintoInt(Copy(StrBits, 1, 2));
      AcpRecebido.TCU_Descriptor_More_Flag1     := BintoInt(Copy(StrBits, 3, 1));
      AcpRecebido.TCU_Descriptor_Length1        := BintoInt(Copy(StrBits, 4, 5));

      PosLimite := PosLimite + AcpRecebido.TCU_Descriptor_Length1;

      if (AcpRecebido.TCU_Descriptor_Length1 >=2) then
      Begin

         StrBits    := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.TCU_Descriptor_Reserved    := BintoInt(Copy(StrBits, 4, 5));

      End;

      if (AcpRecebido.TCU_Descriptor_More_Flag1 = 1 ) and (AcpRecebido.TCU_Descriptor_Length1 >=4) then
      Begin

         StrBits    := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.TCU_Descriptor_IE_Identifier2 := BintoInt(Copy(StrBits, 1, 2));
         AcpRecebido.TCU_Descriptor_More_Flag2     := BintoInt(Copy(StrBits, 3, 1));
         AcpRecebido.TCU_Descriptor_Length2        := BintoInt(Copy(StrBits, 4, 5));


         StrBits    := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.TCU_Descriptor_Device_id := BintoInt(Copy(StrBits, 1, 8));

      End;

      if (AcpRecebido.TCU_Descriptor_More_Flag2 = 1 ) and (AcpRecebido.TCU_Descriptor_Length1 >=6) then
      Begin

         StrBits    := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.TCU_Descriptor_IE_Identifier3 := BintoInt(Copy(StrBits, 1, 2));
         AcpRecebido.TCU_Descriptor_More_Flag3     := BintoInt(Copy(StrBits, 3, 1));
         AcpRecebido.TCU_Descriptor_Length3        := BintoInt(Copy(StrBits, 4, 5));


         StrBits    := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
         AcpRecebido.TCU_Descriptor_Version_id := BintoInt(Copy(StrBits, 1, 8));

      End;

      Result := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_TCU_Descriptor - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_TCU_Descriptor: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;


Function gravacao_acp245.Decode_Reserved(Var PosInicio: Word): Word;
Var
   StrBits: String;
Begin

   Try

      PosLimite := PosInicio+1;

      // MessageFields
      StrBits := CharToStrBinLimit(PacketRec, PosInicio, PosLimite, 1);
      Result  := PosInicio;

      if (PosInicio > PosLimite) then
      Begin
         SalvaLog(Arq_Log,
            'Decode_Reserved - Bytes processados / Deveria Processar: ' +
            InttoStr(PosInicio) + '/' +
            InttoStr(PosLimite));
         Corrigido := 6;
      End;

   Except
      Result := 0;
      SalvaLog(Arq_Log, 'Erro no Decode_Reserved: ' + PacketStr);
      SetLength(PacketTot, 0);
      AcpRecebido.Header_Ok := False;
   End;
End;

Procedure gravacao_acp245.ZeraRecord;
Begin

   // header
   AcpRecebido.Header_Length := 0;
   AcpRecebido.Header_reserved1 := 0;
   AcpRecebido.Header_private_Flag1 := 0;
   AcpRecebido.Header_application_id := 0;
   AcpRecebido.Header_reserved2 := 0;
   AcpRecebido.Header_private_Flag2 := 0;
   AcpRecebido.Header_test_Flag := 0;
   AcpRecebido.Header_Message_type := 0;
   AcpRecebido.Header_version := 0;
   AcpRecebido.Header_version_Flag := 0;
   AcpRecebido.Header_Message_control_Flag0 := 0;
   AcpRecebido.Header_Message_control_Flag1 := 0;
   AcpRecebido.Header_Message_control_Flag2 := 0;
   AcpRecebido.Header_Message_control_Flag3 := 0;
   AcpRecebido.Header_Message_priority := 0;
   AcpRecebido.Header_more_Flag := 0;
   AcpRecebido.Header_Message_Length := 0;
   AcpRecebido.Header_Ok := False;

   // Version
   AcpRecebido.Version_Length := 0;
   AcpRecebido.Version_IEIdentifier := 0;
   AcpRecebido.Version_more_Flag := 0;
   AcpRecebido.Version_Car_Manufacturer := 0;
   AcpRecebido.Version_TCU_Manufacturer := 0;
   AcpRecebido.Version_Major_Hardware_Release := 0;
   AcpRecebido.Version_Major_Software_Release := 0;

   /// / TimeStamp
   AcpRecebido.TimeStamp_Length := 0;
   AcpRecebido.TimeStamp_Msg_DataHora := 0;

   /// / Location
   AcpRecebido.Location_IEIdentifier := 0;
   AcpRecebido.Location_more_Flag := 0;
   AcpRecebido.Location_Length := 0;

   // Current GPSRawData Element
   AcpRecebido.GPS_Current_RawData_IEIdentifier := 0;
   AcpRecebido.GPS_Current_RawData_More_Flag := 0;
   AcpRecebido.GPS_Current_RawData_Length := 0;
   AcpRecebido.GPS_Current_RawData_Number_Satellites := 0;
   AcpRecebido.GPS_Current_Atualizado := 0;
   AcpRecebido.GPS_Current_Angulo := 0;

   // Location Current GPS Coding
   AcpRecebido.GPS_Current_Coding_IEIdentifier := 0;
   AcpRecebido.GPS_Current_Coding_More_Flag := 0;
   AcpRecebido.GPS_Current_Coding_Length := 0;
   AcpRecebido.GPS_Current_Coding_More_Flag1 := 0;
   AcpRecebido.GPS_Current_Coding_Location_Flag1 := 0;
   AcpRecebido.GPS_Current_Coding_More_Flag2 := 0;
   AcpRecebido.GPS_Current_Coding_Location_Flag2 := 0;
   AcpRecebido.GPS_Current_Coding_AreaType := 0;
   AcpRecebido.GPS_Current_Coding_LocationTypeCoding := 0;
   AcpRecebido.GPS_Current_Coding_Reserved := 0;
   AcpRecebido.GPS_Current_Coding_More_Flag3 := 0;
   AcpRecebido.GPS_Current_Coding_Time_Difference := 0;
   AcpRecebido.GPS_Current_Coding_Longitude := 0;
   AcpRecebido.GPS_Current_Coding_Latitude := 0;
   AcpRecebido.GPS_Current_Coding_Altitude := 0;
   AcpRecebido.GPS_Current_Coding_Position_Estimate_Value := 0;
   AcpRecebido.GPS_Current_Coding_Position_Estimate_Type := 0;
   AcpRecebido.GPS_Current_Coding_Heading_Estimate_Type := 0;
   AcpRecebido.GPS_Current_Coding_Heading_Estimate_Value := 0;
   AcpRecebido.GPS_Current_Coding_Distance_Flag := 0;
   AcpRecebido.GPS_Current_Coding_Time_Flag := 0;
   AcpRecebido.GPS_Current_Coding_Velocity := 0;

   // Current GPSRawData Element
   AcpRecebido.GPS_Prior_RawData_IEIdentifier := 0;
   AcpRecebido.GPS_Prior_RawData_More_Flag := 0;
   AcpRecebido.GPS_Prior_RawData_Length := 0;
   AcpRecebido.GPS_Prior_RawData_Number_Satellites := 0;
   AcpRecebido.GPS_Prior_Atualizado := 0;
   AcpRecebido.GPS_Prior_Angulo := 0;


   // Location Current GPS Coding
   AcpRecebido.GPS_Prior_Coding_IEIdentifier := 0;
   AcpRecebido.GPS_Prior_Coding_More_Flag := 0;
   AcpRecebido.GPS_Prior_Coding_Length := 0;
   AcpRecebido.GPS_Prior_Coding_More_Flag1 := 0;
   AcpRecebido.GPS_Prior_Coding_Location_Flag1 := 0;
   AcpRecebido.GPS_Prior_Coding_More_Flag2 := 0;
   AcpRecebido.GPS_Prior_Coding_Location_Flag2 := 0;
   AcpRecebido.GPS_Prior_Coding_AreaType := 0;
   AcpRecebido.GPS_Prior_Coding_LocationTypeCoding := 0;
   AcpRecebido.GPS_Prior_Coding_Reserved := 0;

   AcpRecebido.GPS_Prior_Coding_More_Flag3 := 0;
   AcpRecebido.GPS_Prior_Coding_Time_Difference := 0;
   AcpRecebido.GPS_Prior_Coding_Longitude := 0;
   AcpRecebido.GPS_Prior_Coding_Latitude := 0;
   AcpRecebido.GPS_Prior_Coding_Altitude := 0;
   AcpRecebido.GPS_Prior_Coding_Position_Estimate_Value := 0;
   AcpRecebido.GPS_Prior_Coding_Position_Estimate_Type := 0;
   AcpRecebido.GPS_Prior_Coding_Heading_Estimate_Type := 0;
   AcpRecebido.GPS_Prior_Coding_Heading_Estimate_Value := 0;
   AcpRecebido.GPS_Prior_Coding_Distance_Flag := 0;
   AcpRecebido.GPS_Prior_Coding_Time_Flag := 0;
   AcpRecebido.GPS_Prior_Coding_Velocity := 0;

   // Current Dead Reckoning Data
   AcpRecebido.CDRD_WGS84_IEIdentifier := 0;
   AcpRecebido.CDRD_WGS84_more_Flag := 0;
   AcpRecebido.CDRD_WGS84_Length := 0;
   AcpRecebido.CDRD_WGS84_Latitude := 0;
   AcpRecebido.CDRD_WGS84_Longitude := 0;

   // Array of Area Location Delta Coding
   AcpRecebido.Area_Delta_IEIdentifier := 0;
   AcpRecebido.Area_Delta_more_Flag := 0;
   AcpRecebido.Area_Delta_Length := 0;

   // Vehicle
   AcpRecebido.Vehicle_IEIdentifier := 0;
   AcpRecebido.Vehicle_more_Flag := 0;
   AcpRecebido.Vehicle_Length := 0;
   AcpRecebido.Vehicle_Flag_Addl_Flag1 := 0;
   AcpRecebido.Vehicle_Flag_Language := 0;
   AcpRecebido.Vehicle_Flag_VIN := 0;
   AcpRecebido.Vehicle_Flag_TCU_Serial := 0;
   AcpRecebido.Vehicle_Flag_Vehicle_Color := 0;
   AcpRecebido.Vehicle_Flag_Vehicle_Model := 0;
   AcpRecebido.Vehicle_Flag_License_Plate := 0;
   AcpRecebido.Vehicle_Flag_IMEI := 0;
   AcpRecebido.Vehicle_Flag_Addl_Flag2 := 0;
   AcpRecebido.Vehicle_Flag_Vehicle_Model_year := 0;
   AcpRecebido.Vehicle_Flag_SIMCard_ID := 0;
   AcpRecebido.Vehicle_Flag_Auth_Key := 0;
   AcpRecebido.Vehicle_Language := '';
   AcpRecebido.Vehicle_VIN := '';
   AcpRecebido.Vehicle_TCU_Serial := 0;
   AcpRecebido.Vehicle_Vehicle_Color := '';
   AcpRecebido.Vehicle_Vehicle_Model := '';
   AcpRecebido.Vehicle_License_Plate := '';
   AcpRecebido.Vehicle_IMEI := '';
   AcpRecebido.Vehicle_Vehicle_Model_year := 0;
   AcpRecebido.Vehicle_SIMCard_ID := '';
   AcpRecebido.Vehicle_Auth_Key := '';

   // BreakDown
   AcpRecebido.BreakDown_IEIdentifier := 0;
   AcpRecebido.BreakDown_more_Flag := 0;
   AcpRecebido.BreakDown_Length := 0;
   AcpRecebido.BreakDown_Breakdown_Flag1 := 0;
   AcpRecebido.BreakDown_Breakdown_Flag2 := 0;
   AcpRecebido.BreakDown_Breakdown_Flag3 := 0;
   AcpRecebido.BreakDown_Breakdown_Additional := 0;
   AcpRecebido.BreakDown_Breakdown_sensor := 0;
   AcpRecebido.BreakDown_Breakdown_Data := '';
   AcpRecebido.BreakDown_Chave := 0;
   AcpRecebido.BreakDown_Bateria_Violada := 0;
   AcpRecebido.BreakDown_Bateria_Religada := 0;
   AcpRecebido.BreakDown_Status := 0;

   // Information
   AcpRecebido.Information_IEIdentifier := 0;
   AcpRecebido.Information_more_Flag := 0;
   AcpRecebido.Information_Length := 0;
   AcpRecebido.Information_Type := 0;
   AcpRecebido.Information_RawData := '';

   // MessageFields
   AcpRecebido.Message_more_Flag := 0;
   AcpRecebido.Message_TargetApplicationID := 0;
   AcpRecebido.Message_ApplFlag1 := 0;
   AcpRecebido.Message_ControlFlag1 := 0;
   AcpRecebido.Message_StatusFlag1 := 0;
   AcpRecebido.Message_TCUResponseFlag := 0;
   AcpRecebido.Message_Reserved := 0;
   AcpRecebido.Message_Length := 0;

   // Control Function
   AcpRecebido.Control_Function_IEIdentifier := 0;
   AcpRecebido.Control_Function_more_Flag := 0;
   AcpRecebido.Control_Function_Length := 0;
   AcpRecebido.Control_Function_Entity_ID := 0;
   AcpRecebido.Control_Function_Reserved := 0;
   AcpRecebido.Control_Function_Transmit_Units := 0;
   AcpRecebido.Control_Function_Transmit_Interval := 0;

   AcpDataError := nil;
   AcpTCU_Data  := nil;

End;

{ A função dormir deve ser repetida em cada thread, prar evitar sincronismo}
Procedure gravacao_acp245.Dormir(pTempo: Word);
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

Procedure gravacao_acp245.CargaAcp;
Var
   Contador: Word;
   // Roda o Sleep em slice de 1/20 para checar o Final da thread
Begin
   For Contador := 1 to 20 do
   Begin
      if Not Encerrar then
         Sleep(10);
   End
End;


Function  gravacao_acp245.CargaDispositivos():Boolean;
Begin

Result := False;

if conn.Connected then
Try
   QRyGeral.SQL.Clear;
   QRyGeral.SQL.Add('Select * from acp245.dispositivos;');
   QRyGeral.Open;
   while (Not QRyGeral.Eof) do
   Begin
      dispositivos.Append;
      Dispositivos.FieldByName('id').AsString                   :=   QRyGeral.FieldByName('id').AsString;
      Dispositivos.FieldByName('car_manufacturer').AsString     :=   QRyGeral.FieldByName('car_manufacturer').AsString;
      Dispositivos.FieldByName('tcu_manufacturer').AsString     :=   QRyGeral.FieldByName('tcu_manufacturer').AsString;
      Dispositivos.FieldByName('hardware_release').AsString     :=   QRyGeral.FieldByName('hardware_release').AsString;
      Dispositivos.FieldByName('software_release').AsString     :=   QRyGeral.FieldByName('software_release').AsString;
      Dispositivos.FieldByName('vehicle_vin_number').AsString   :=   QRyGeral.FieldByName('vehicle_vin_number').AsString;
      Dispositivos.FieldByName('vehicle_tcu_serial').AsString   :=   QRyGeral.FieldByName('vehicle_tcu_serial').AsString;
      Dispositivos.FieldByName('vehicle_flag1').AsString        :=   QRyGeral.FieldByName('vehicle_flag1').AsString;
      Dispositivos.FieldByName('vehicle_flag2').AsString        :=   QRyGeral.FieldByName('vehicle_flag2').AsString;
      Dispositivos.FieldByName('language').AsString             :=   QRyGeral.FieldByName('language').AsString;
      Dispositivos.FieldByName('model_year').AsString           :=   QRyGeral.FieldByName('model_year').AsString;
      Dispositivos.FieldByName('vin').AsString                  :=   QRyGeral.FieldByName('vin').AsString;
      Dispositivos.FieldByName('tcu_serial').AsString           :=   QRyGeral.FieldByName('tcu_serial').AsString;
      Dispositivos.FieldByName('license_plate').AsString        :=   QRyGeral.FieldByName('license_plate').AsString;
      Dispositivos.FieldByName('vehicle_color').AsString        :=   QRyGeral.FieldByName('vehicle_color').AsString;
      Dispositivos.FieldByName('vehicle_model').AsString        :=   QRyGeral.FieldByName('vehicle_model').AsString;
      Dispositivos.FieldByName('imei').AsString                 :=   QRyGeral.FieldByName('imei').AsString;
      Dispositivos.FieldByName('sim_card_id').AsString          :=   QRyGeral.FieldByName('sim_card_id').AsString;
      Dispositivos.FieldByName('auth_key').AsString             :=   QRyGeral.FieldByName('auth_key').AsString;
      Dispositivos.FieldByName('device_id').AsString            :=   QRyGeral.FieldByName('device_id').AsString;
      Dispositivos.FieldByName('version_id').AsString           :=   QRyGeral.FieldByName('version_id').AsString;
      Dispositivos.FieldByName('host1').AsString                :=   QRyGeral.FieldByName('host1').AsString;
      Dispositivos.FieldByName('porta1').AsString               :=   QRyGeral.FieldByName('porta1').AsString;
      Dispositivos.FieldByName('protocolo1').AsString           :=   QRyGeral.FieldByName('protocolo1').AsString;
      Dispositivos.FieldByName('host2').AsString                :=   QRyGeral.FieldByName('host2').AsString;
      Dispositivos.FieldByName('porta2').AsString               :=   QRyGeral.FieldByName('porta2').AsString;
      Dispositivos.FieldByName('protocolo2').AsString           :=   QRyGeral.FieldByName('protocolo2').AsString;
      Dispositivos.FieldByName('operadora').AsString            :=   QRyGeral.FieldByName('operadora').AsString;
      Dispositivos.FieldByName('application_version').AsString  :=   QRyGeral.FieldByName('application_version').AsString;
      Dispositivos.FieldByName('message_control').AsString      :=   QRyGeral.FieldByName('message_control').AsString;
      Dispositivos.FieldByName('modificado').AsBoolean          :=   False;
      dispositivos.Post;
      QRyGeral.Next;
   End;
   QRyGeral.Close;
   Result := True;
Except
   Result := False;
End;
End;

Function  gravacao_acp245.AtualizaDispositivos(pID: String):Boolean;

Begin

   Result := False;

   Dispositivos.Filtered := False;
   Dispositivos.Filter := 'ID = ' + pId;
   Dispositivos.Filtered := True;
      Dispositivos.First;
   If Not Dispositivos.Eof Then
      //Atualiza
   Else
   Begin
      //Inclui
      Dispositivos.Append;
      Dispositivos.FieldByName('ID').AsString                 := pId;
      Dispositivos.FieldByName('car_manufacturer').Asinteger  := AcpRecebido.Version_Car_Manufacturer;
      Dispositivos.FieldByName('tcu_manufacturer').Asinteger  := AcpRecebido.Version_TCU_Manufacturer;
      Dispositivos.FieldByName('hardware_release').Asinteger  := AcpRecebido.Version_Major_Hardware_Release;
      Dispositivos.FieldByName('software_release').Asinteger  := AcpRecebido.Version_Major_Software_Release;
      Dispositivos.FieldByName('vehicle_vin_number').AsString := AcpRecebido.Vehicle_VIN;
      Dispositivos.FieldByName('vehicle_tcu_serial').AsString := InttoStr(AcpRecebido.Vehicle_TCU_Serial);
//      Dispositivos.FieldByName('vehicle_flag1').AsString      :=
//      Dispositivos.FieldByName('vehicle_flag2').AsString      :=
      Dispositivos.FieldByName('language').AsString           := AcpRecebido.Vehicle_Language;
      Dispositivos.FieldByName('model_year').Asinteger        := AcpRecebido.Vehicle_Vehicle_Model_year;
      Dispositivos.FieldByName('vin').AsString                := AcpRecebido.Vehicle_VIN;
//      Dispositivos.FieldByName('tcu_serial').AsString :=
      Dispositivos.FieldByName('license_plate').AsString      := AcpRecebido.Vehicle_License_Plate;
      Dispositivos.FieldByName('vehicle_color').AsString      := AcpRecebido.Vehicle_Vehicle_Color;
      Dispositivos.FieldByName('vehicle_model').AsString      := AcpRecebido.Vehicle_Vehicle_Model;
      Dispositivos.FieldByName('imei').AsString               := AcpRecebido.Vehicle_IMEI;
      Dispositivos.FieldByName('sim_card_id').AsString        := AcpRecebido.Vehicle_SIMCard_ID;
      Dispositivos.FieldByName('auth_key').AsString           := AcpRecebido.Vehicle_Auth_Key;
//      Dispositivos.FieldByName('device_id').AsString :=
//      Dispositivos.FieldByName('version_id').AsString :=
//      Dispositivos.FieldByName('host1').AsString :=
//      Dispositivos.FieldByName('porta1').AsString :=
//      Dispositivos.FieldByName('protocolo1').AsString :=
//      Dispositivos.FieldByName('host2').AsString :=
//      Dispositivos.FieldByName('porta2').AsString :=
//      Dispositivos.FieldByName('protocolo2').AsString :=
//      Dispositivos.FieldByName('operadora').AsString :=
//      Dispositivos.FieldByName('application_version').Asinteger :=
//      Dispositivos.FieldByName('message_control').Asinteger :=
      Dispositivos.FieldByName('modificado').AsBoolean        := True;
      Dispositivos.Post;

   End;

   Dispositivos.Filtered := False;

   Result := True;

End;

Function  gravacao_acp245.GravaDispositivos():Boolean;
Var Sql: String;Begin

   Dispositivos.Filtered := False;
   Dispositivos.First;

   while Not Dispositivos.Eof do
   Begin

      if (Dispositivos.FieldByName('modificado').AsBoolean) then
      Begin
         Sql := 'Update acp245.dispositivos Set ';
         Sql := Sql + 'ID= ' + QuotedStr(Dispositivos.FieldByName('ID').AsString) + ',';
         Sql := Sql + 'car_manufacturer = ' + InttoStr(Dispositivos.FieldByName('car_manufacturer').Asinteger) + ',';
         Sql := Sql + 'tcu_manufacturer = ' + InttoStr(Dispositivos.FieldByName('tcu_manufacturer').Asinteger) + ',';
         Sql := Sql + 'hardware_release = ' + InttoStr(Dispositivos.FieldByName('hardware_release').Asinteger) + ',';
         Sql := Sql + 'software_release = ' + InttoStr(Dispositivos.FieldByName('software_release').Asinteger) + ',';
         Sql := Sql + 'vehicle_vin_number = ' + QuotedStr(Dispositivos.FieldByName('vehicle_vin_number').AsString) + ',';
         Sql := Sql + 'vehicle_tcu_serial = ' + QuotedStr(Dispositivos.FieldByName('vehicle_tcu_serial').AsString) + ',';
         Sql := Sql + 'language = ' + QuotedStr(Dispositivos.FieldByName('language').AsString) + ',';
         Sql := Sql + 'model_year = ' + InttoStr(Dispositivos.FieldByName('model_year').Asinteger) + ',';
         Sql := Sql + 'vin = ' + QuotedStr(Dispositivos.FieldByName('vin').AsString) + ',';
         Sql := Sql + 'license_plate' + QuotedStr(Dispositivos.FieldByName('license_plate').AsString) + ',';
         Sql := Sql + 'vehicle_color' + QuotedStr(Dispositivos.FieldByName('vehicle_color').AsString) + ',';
         Sql := Sql + 'vehicle_model' + QuotedStr(Dispositivos.FieldByName('vehicle_model').AsString) + ',';
         Sql := Sql + 'imei' + QuotedStr(Dispositivos.FieldByName('imei').AsString) + ',';
         Sql := Sql + 'sim_card_id' + QuotedStr(Dispositivos.FieldByName('sim_card_id').AsString) + ',';
         Sql := Sql + 'auth_key' + QuotedStr(Dispositivos.FieldByName('auth_key').AsString) + ',';
         Sql := Sql + ';';

         Try
            QRyGeral.SQL.Clear;
            QRyGeral.SQL.Add(Sql);
            QRyGeral.ExecSql;
            Dispositivos.Edit;
            Dispositivos.FieldByName('modificado').AsBoolean := False;
            Dispositivos.Post;
         Except

            Result := False;
            SalvaLog(Arq_Log,'Erro ao Atualizar Dispositivos - Thread: ' + InttoStr(ThreadId));

         End;

      End;

      Dispositivos.Next;

   End;
   Result := True;

End;
end.




unit thread_gravacao_ET06;

interface

uses
   Windows, SysUtils, Classes, Math, StrUtils, //ZConnection,
   DB, DBClient, DateUtils, //ZDataset, ZAbstractRODataset,
   //ZStoredProcedure,
   FuncColetor, FunET06;
   // Record Utilizado na Gravacao do Pacote SunTech (Network Parameters Setting)
Const SunTech_NTW: Array[1..10] Of String =
      ('AUTH','APN','USER_ID','USER_PWD','SEVER_IP_1','SEVER_PORT_1','SEVER_IP_2','SEVER_PORT_2','SMS_NO','PIN_NO');
   // Record Utilizado na Gravacao do Pacote SunTech (Report Parameter Setting)
      SunTech_RPT: Array[1..10] Of String =
      ('AUTH','T1','T2','T3','A1','SND_DIST','T4','SMS_T1','SMS_T2','SMS_PACK_NO');
   // Record Utilizado na Gravacao do Pacote SunTech (Event Parameter Setting)
      SunTech_EVT: Array[1..24] Of String =
      ('IGNITION','T1','T2','IN1_TYPE','IN2_TYPE','IN3_TYPE','IN1_CHAT','IN2_CHAT','IN3_CHAT','OUT1_TYPE','OUT2_TYPE',
       'OUT1_ACTIVE','OUT2_ACTIVE','PULSE1_NO','PULSE1_ON','PULSE1_OFF','PULSE2_NO','PULSE2_ON','PULSE2_OFF','IN4_TYPE',
       'IN5_TYPE','IN4_CHAT','IN5_CHAT','BAUD');
   // Record Utilizado na Gravacao do Pacote SunTech (GSM Parameter Setting)
      SunTech_GSM: Array[1..13] Of String =
      ('SMS_LOCK','SMS_MT1','SMS_MT2','SMS_MT3','SMS_MT4','IN_CALL_LOCK','CALL_MT1','CALL_MT2','CALL_MT3','CALL_MT4',
       'CALL_MT5','CALL_MO1','CALL_MO2');
   // Record Utilizado na Gravacao do Pacote SunTech (Service Parameter Setting)
      SunTech_SVC: Array[1..13] Of String =
      ('PARKING_LOCK','SPEED_LIMIT','PWR_DN','CON_TYPE','ZIP','GROUP_SEND','MP_CHK','ANT_CHK','BAT_CHK','M_SENSOR','CALL',
       'GEO_FENCE','DAT_LOG');
   // Record Utilizado na Gravacao do Pacote SunTech (Additional Parameters)
      SunTech_ADP: Array[1..10] Of String =
      ('SVR_TYPE','B_SVR_TYPE','UDP_ACK','DEV_PORT','Reserved1','Reserved2','Reserved3','Reserved4','Reserved5','Reserved6');
   // Record Utilizado na Gravacao do Pacote SunTech (Parameters of Main Voltage)
      SunTech_MBV: Array[1..7] Of String =
      ('CHR_STOP_THRES_12','CHR_STOP_THRES_24','DECIDE_BAT_24','OPERATION_STOP_THRES_12','OPERATION_STOP_THRES_24','IGNDET_H','IGNDET_L');
   // Record Utilizado na Gravacao do Pacote SunTech (DEV)
      SunTech_DEV: Array[1..4] Of String =
      ('OUT1','OUT2','PWR_DN','BAT_CON');
   // Record Utilizado na Gravacao do Pacote SunTech (DEV)
      SunTech_MSR: Array[1..4] Of String =
      ('SHOCK_DELAY','MOTION_THRES','SHOCK_THRES','COLL_THRES');

Type

   Gravacao_ET06 = class(TThread)
   public

      // Parametros recebidos
      db_inserts: Integer;   // Insert Simultaneo
      db_hostname: String;   // Nome do Host
      db_username: String;   // Usuario
      db_database: String;   // Database
      db_password: String;   // Password
      db_tablecarga: String; // Tabela de carga
      marc_codigo: String;  //C?digo da Tecnologia
      Arq_Log: String;
      Arq_Err: String;
      Arq_Sql: String;
      Arq_Proce: String;
      DirInbox: String;
      DirProcess: String;
      DirErros: String;
      DirSql: String;
      Debug_id: String;
      PortaLocal: Integer;
      Encerrar: Boolean;
      Debug: SmallInt;
      ThreadId: Word;
      Separador: String;
      gravatemp : string;
      contador_arquivo : Integer;
      quant_sql : Integer;

      // Objetos
      ArqPendentes: Integer;
      Arq_inbox: String;
      equip,valid,pporta,pip_remoto,pct_inteiro : string;
      Suntech_comum: Pack_SunTech;

      SqlResposta: String;

   private
      { Private declarations }
      Processar: tClientDataSet;

   protected

      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaDatabase;
      Procedure LimpaRecord();
      Procedure Dormir(pTempo: Word);
      Function  Decode(pPacket: String): String;
      Function  Decode_STT(pPacket: String): String;
      Function  Decode_ALT(pPacket: String): String;
      Function  Decode_EMG(pPacket: String): String;
      Function  Decode_CMD(pPacket: String): String;
      Function  Decode_Generico(pPacket,pTipo: String; pVetor: Array Of String ): String;

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure Gravacao_ET06.Execute;
begin
   Try

      FreeOnTerminate := True;

      Separador := ',';

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

         TcpSrvForm.ThGravacao_ET06_ultimo := Now;

         Sleep(100);

         BuscaArquivo;

         if (Arq_inbox <> '') then
            GravaDatabase
         Else
         Begin
            Dormir(500);
         End;

      End;


   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Grava??o SunTech - Encerrada por Erro: '
         + InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;

end;

Procedure Gravacao_ET06.BuscaArquivo;
Var
   Arquivos: TSearchRec;
Begin
   Try
      ArqPendentes := 0;
      Arq_inbox := '';

      if FindFirst(DirInbox + '\*.ET*' + FormatFloat('00', ThreadId), faArchive,
         Arquivos) = 0 then
      begin
         Arq_inbox := DirInbox + '\' + Arquivos.Name;
         Arq_Sql   := DirSql   + '\' + ExtractFileName(Arq_inbox);
         Arq_Err   := DirErros + '\' + ExtractFileName(Arq_inbox);
         Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_inbox);
      End;

      FindClose(Arquivos);
      Sleep(50);

   Except
      Arq_inbox := '';
   End;

End;

Procedure Gravacao_ET06.GravaDatabase;
Var
   SqlExec: String;
   SqlPendente: String;

Begin
   Try


      Try
         Processar.LoadFromFile(Arq_inbox);
      Except
         SalvaLog(Arq_Log, 'Arquivo n?o Encontrado: ' + Arq_inbox);
         Exit;
      End;

      SqlExec     := '';
      SqlPendente := '';

      Processar.First;

      while Not Processar.Eof do
      Begin

         Try

            if Debug in [2, 5, 9] then
               SalvaLog(Arq_Log, 'Datagrama Recebido:' + Processar.FieldByName('DataGrama').AsString);

            LimpaRecord;

            SqlExec := Decode(Processar.FieldByName('DataGrama').AsString);


            // Se for pacote de tracking
            if Length(SqlExec) > 0  then
            Begin

               SqlPendente := SqlPendente +  SqlExec + ';' + Char(13) + Char(10);

            End;


         Except

            SalvaLog(Arq_Log, 'Erro no Decode: ' + Processar.FieldByName('DataGrama').AsString);

         End;

         Processar.Next;

      End;

      Try
         SalvaArquivo(Arq_Sql, SqlPendente);
         Processar.Close;
         deletefile(Arq_inbox);
      Except
         Processar.SaveToFile(Arq_Err);
         SalvaLog(Arq_Log, 'Erro ao Deletar recebidos: ' + Arq_inbox);
      End;

      Sleep(10);

   Except
      SalvaLog(Arq_Log, 'Erro na Procedure GravaDatabase: ' + Arq_inbox);
   End;
End;

Function Gravacao_ET06.Decode(pPacket: String): String;
Var
   Strproc:   String;
   SqlTracking: String;
Begin
   Result := '';
   Try
      pct_inteiro    := pPacket;
      Strproc        := pPacket;
      LimpaRecord;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_comum.HDR      := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      //Pacotes STT/ALT/ALV Diretos
      //Outros sao "Res" = Resposta
      if Strproc = 'Res' then
      Begin
         StringProcessar(pPacket, Strproc, Separador);
      End;

      Suntech_comum.DeviceID := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_comum.Versao   := Strproc;

      //Truque sujo !!!!
      pPacket := pPacket + ',';

      if Suntech_comum.HDR = '*ET' Then    //SA200STT - Status Report
         SqlTracking := Decode_STT(pPacket)
      Else if Suntech_comum.HDR = 'SA200ALT' Then
         SqlTracking := Decode_ALT(pPacket)
      Else if Suntech_comum.HDR = 'SA200EMG' Then
         SqlTracking := Decode_EMG(pPacket)
      Else if Suntech_comum.HDR = 'SA200CMD' Then
         SqlTracking := Decode_CMD(pPacket)
      Else if Suntech_comum.HDR = 'SA200NTW' Then
         SqlTracking := Decode_Generico(pPacket,'NTW',SunTech_NTW)
      Else if Suntech_comum.HDR = 'SA200RPT' Then
         SqlTracking := Decode_Generico(pPacket,'RPT',SunTech_RPT)
      Else if Suntech_comum.HDR = 'SA200EVT' Then
         SqlTracking := Decode_Generico(pPacket,'EVT',SunTech_EVT)
      Else if Suntech_comum.HDR = 'SA200GSM' Then
         SqlTracking := Decode_Generico(pPacket,'GSM',SunTech_GSM)
      Else if Suntech_comum.HDR = 'SA200SVC' Then
         SqlTracking := Decode_Generico(pPacket,'SVC',SunTech_SVC)
      Else
      Begin

         SqlTracking := '';
         SalvaLog(Arq_Log, 'Pacote n?o previsto: ' + Processar.FieldByName('DataGrama').AsString);

      End;

      Result := SqlTracking;

      //'EMG' 'ALT'
      //'ALV' 'NTW' 'RPT' 'EVT' 'GSM' 'SVC' 'ADP' 'MBV' 'MSR' 'CGF' 'NPT' 'CMD' 'DEX' 'UEX' 'STR'

   Except
      SalvaLog(Arq_Log, 'Erro ao executar decode: Id/Packet' + Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);
   End;
End;


//SA200STT - Status Report
Function Gravacao_ET06.Decode_STT(pPacket: String): String;
Var
   Strproc,vtensao,sinal:   String;
   SqlTracking,SqlTracking1: String;
   Suntech_STT: Pack_SunTech_STT;
  S1, S2,ip,pact: string;
  vdata,nova_dt:TDateTime;
  tempo : Ttime;
  i,w : integer;
  pstatus : array[1..4] of string;
  firstbyte : array[1..8] of string;
  secondbyte : array[1..8] of string;
Begin
   Result := '';
   SqlTracking:= 'Insert into nexsat.' + db_tablecarga +  '(ID, DH_GPS, LATITUDE, LONGITUDE, VELOCIDADE, ODOMETRO, '
         + 'ANGULO, QTDADE_SATELITE, TENSAO, HORIMETRO, ATUALIZADO, BATERIA, CHAVE, AUX1, AUX2, AUX3, SAI_1, '
         + 'SAI_2, PORTA, IP_REMOTO, PORTA_REMOTO, MARC_CODIGO ) ' ;

   Try
// come?o da leitura e grava??o dos pacotes do ET
        pPacket := pct_inteiro;
        StringProcessar(pPacket, Strproc, Separador);
        equip                    := Strproc;  // modelo do equip.

        StringProcessar(pPacket, Strproc, Separador);
        Suntech_Comum.DeviceID   := Strproc;// imei/id trim(copy(Strproc,6,20));
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C13_MODE     := Strproc;  //comando
        SqlTracking1:= 'Insert into nexsat.posicao_tmp(id,pacote,marc_codigo,data_rec) Values(';
        SqlTracking1:= SqlTracking1+QuotedStr(Suntech_Comum.DeviceID)+','+QuotedStr(pct_inteiro)+','+QuotedStr('50')+',current_timestamp)' ;
//        SqlTracking:= 'Insert ignore into nexsat.tipos_eventos(evento,marc_codigo) Values(';
//        SqlTracking:= SqlTracking+QuotedStr(Suntech_STT.C13_MODE)+','+QuotedStr('50')+')' ;
//        Result := SqlTracking;
//        Result := '';
        if (Suntech_STT.C13_MODE = 'HB') or (Suntech_STT.C13_MODE = 'CC')
         or (Suntech_STT.C13_MODE = 'AM')then
        begin
        if (Suntech_STT.C13_MODE = 'CC') then
          begin
            StringProcessar(pPacket, Strproc, Separador);
            valid                    := Strproc;
          end;
        StringProcessar(pPacket, Strproc, Separador);
        valid                    := Strproc;
        if valid = 'A' then
          valid := '1'
        else
          valid := '0';
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C01_DATE     := '20';
        for i := 1 to Length(Strproc)-1 do
          begin
            if (i <> 2) and (i <> 4) then
              Suntech_STT.C01_DATE := Suntech_STT.C01_DATE + CompletaEspaco(inttostr(hexaToInt(copy(Strproc,i,2))),2,'0');
          end;
//        if strtodate(Suntech_STT.C01_DATE) >  then

        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C02_TIME := '';
        for i := 1 to Length(Strproc)-1 do
          begin
            if (i <> 2) and (i <> 4) and (i < 6) then
              Suntech_STT.C02_TIME := Suntech_STT.C02_TIME + CompletaEspaco(inttostr(hexaToInt(copy(Strproc,i,2))),2,'0');
          end;
        Suntech_STT.C02_TIME := trata_time(Suntech_STT.C02_TIME);
        //***** Ver hora UTC e ajustar por comando
        //***** Comando  *ET,ID da Pe?a,SQ,0# 28/08/2014
        if copy(Suntech_STT.C01_DATE,1,4) = '2000' then
          begin
            Suntech_STT.C01_DATE := copy(datetostr(now()),7,4)+copy(datetostr(now()),4,2)+copy(datetostr(now()),1,2);
            Suntech_STT.C02_TIME := timetostr(inchour(now(),3));
          end;
//        LimpaDataSuntec(Suntech_STT.C01_DATE,Suntech_STT.C02_TIME);

        StringProcessar(pPacket, Strproc, Separador);
        if HexToNumber(copy(Strproc,1,1)) = '8' then
          sinal := '-'
        else
          sinal := '';
        Suntech_STT.C04_LAT := sinal+ troca(FloatToStr(strtoint(HexToNumber(copy(Strproc,2,7)))/600000));  //latitude
        StringProcessar(pPacket, Strproc, Separador);
        if HexToNumber(copy(Strproc,1,1)) = '8' then
          sinal := '-'
        else
          sinal := '';
        Suntech_STT.C05_LON := sinal+ troca(FloatToStr(strtoint(HexToNumber(copy(Strproc,2,7)))/600000));  //longitude
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C06_SPD      := FloatToStr(strtoint(HexToNumber(Strproc))/100); //velocidade
        if StrToFloat(Suntech_STT.C06_SPD) < 2 then
          Suntech_STT.C06_SPD := '0'
        else
          Suntech_STT.C06_SPD := IntToStr(Round(strtofloat(Suntech_STT.C06_SPD)));
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C07_CRS      := troca(FloatToStr(strtoint(HexToNumber(Strproc))/100)); //angulo
        StringProcessar(pPacket, Strproc, Separador);
        w := 1;
        pstatus[w] := HexaToBin(copy(Strproc,1,2));
        Inc(w);
        pstatus[w] := HexaToBin(copy(Strproc,3,2));
        Inc(w);
        pstatus[w] := HexaToBin(copy(Strproc,5,2));
        Inc(w);
        pstatus[w] := HexaToBin(copy(Strproc,7,2));
        for i := 1 to Length(pstatus[1])-1 do
          firstbyte[i] := copy(pstatus[1],i,1);
        Suntech_STT.C11_PWR_VOLT := firstbyte[5];       //bateria
        Suntech_STT.C22_VEL_EX := firstbyte[1];    //Veloc Ex
        Suntech_STT.C19_GPSM := firstbyte[4];    //gps v4antopen
        for i := 1 to Length(pstatus[2])-1 do
          secondbyte[i] := copy(pstatus[2],i,1);
        if ((firstbyte[2] = '1') or (secondbyte[1] = '1')) then
//          Suntech_STT.C12_IO       := secondbyte[1];   //chave
          Suntech_STT.C12_IO       := '1'   //chave
        else
          Suntech_STT.C12_IO       := '0';   //chave

        if Suntech_STT.C12_IO = '0' then
          Suntech_STT.C06_SPD := '0';
        Suntech_STT.C21_SAI1     := secondbyte[5];   //Sai1
        Suntech_STT.C20_PANICO       := secondbyte[8];   //Panico
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C03_CELL     := Strproc;   //sinal
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C18_PWR := Strproc;       //power bateria
        vtensao := Suntech_STT.C18_PWR;
        if strtoint(Suntech_STT.C18_PWR) = 100 then
          Suntech_STT.C18_PWR := '0'
        else
          Suntech_STT.C18_PWR := '1';
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C10_DIST     := HexToNumber(Strproc);    // oil Oleo/odometro
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C09_FIX      := HexToNumber(Strproc);  // lc km
        if strtoint(Suntech_STT.C09_FIX) < 0 then
          Suntech_STT.C09_FIX      := '0';
        Separador:='#';
        StringProcessar(pPacket, Strproc, Separador);
        Suntech_STT.C15_H_METER     := Strproc;  //distancia/altitude
        Suntech_STT.C08_SATT := '0' ;//qtde de satelite
        Separador:=',';
//        if copy(Suntech_STT.C04_LAT,1,2) <> '-0' then
        SqlTracking:= 'Insert into nexsat.posicoes_carga(ID, DH_GPS, LATITUDE, LONGITUDE, VELOCIDADE, ODOMETRO, '
           + 'ANGULO, QTDADE_SATELITE, TENSAO, HORIMETRO, ATUALIZADO, BATERIA, CHAVE, AUX1, AUX2, AUX3, SAI_1, '
           + 'SAI_2, PORTA, IP_REMOTO, PORTA_REMOTO, MARC_CODIGO, DATA_REC, VEL_EXCESS ) ' ;
        SqlTracking := SqlTracking + ' Values(';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_Comum.DeviceID) + ',';     //ID
//        SqlTracking := SqlTracking + QUOTEDSTR(LimpaDataSuntec(Suntech_STT.C01_DATE,Suntech_STT.C02_TIME)) +','; //DH_GPS
        SqlTracking := SqlTracking + 'DATE_SUB(' + QUOTEDSTR(LimpaDataSuntec(Suntech_STT.C01_DATE,Suntech_STT.C02_TIME)) +
                                             ',INTERVAL  hour(timediff(now(),utc_timestamp())) Hour),'; //DH_GPS
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C04_LAT) + ',';                   //LATITUDE
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C05_LON) + ',';                   //LONGITUDE
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C06_SPD) + ',';                   //VELOCIDADE
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C09_FIX) + ',';                  //ODOMETRO
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C07_CRS) + ',';                   //ANGULO
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C08_SATT) + ',';                  //QTDADE_SATELITE  /
        SqlTracking := SqlTracking + QUOTEDSTR(vtensao) + ',0,';                  //tensao  /
        SqlTracking := SqlTracking + QUOTEDSTR(valid)+ ','  ;                                     //ATUALIZAD
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C18_PWR) + ',';              //TENSAO / Bateria
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C12_IO) + ',0,0,0,';          //CHAVE
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C21_SAI1) + ',0,';                   //said 1
        SqlTracking := SqlTracking + QUOTEDSTR(inttoStr(PortaLocal)) + ',';          //porta
        SqlTracking := SqlTracking + QUOTEDSTR(Processar.FieldByName('IP').AsString) + ',';  //IP_REMOTO
        SqlTracking := SqlTracking + Processar.FieldByName('Porta').AsString + ',';  //PORTA_REMOTO
        SqlTracking := SqlTracking + '50,CURRENT_TIMESTAMP' + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C22_VEL_EX) + ')';    //veloc.Excess
        if gravatemp = 'S'  then
          Result := SqlTracking + ';' + Char(13) + Char(10) + SqlTracking1
        else
          Result := SqlTracking + ';';
        end
        else
          if gravatemp = 'S'  then
            Result := SqlTracking1;
   Except
      Result := '';
      SalvaLog(Arq_Log, 'Erro ao executar decode STT:' + Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);
   End;
End;

//SA200ALT - Alert Report
Function Gravacao_ET06.Decode_ALT(pPacket: String): String;
Var
   Strproc:     String;
   SqlTracking: String;
   SqlAlerta:   String;
   Suntech_ALT: Pack_SunTech_ALT;

Begin
   Result := '';
   SqlTracking:= 'Insert into nexsat.' + db_tablecarga +  '(ID, DH_GPS, LATITUDE, LONGITUDE, VELOCIDADE, ODOMETRO, '
         + 'ANGULO, QTDADE_SATELITE, ATUALIZADO, TENSAO, CHAVE, AUX1, AUX2, AUX3, SAI_1, SAI_2, BREAKDOWN1, '
         + 'BATERIA_VIOLADA, BATERIA_RELIGADA, PORTA, IP_REMOTO, PORTA_REMOTO, MARC_CODIGO ) ' ;
   SqlAlerta:= 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) ' ;

   Try

      Strproc          := pPacket;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C01_DATE     := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C02_TIME     := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C03_CELL     := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C04_LAT      := LimpaFloatStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C05_LON      := LimpaFloatStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C06_SPD      := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C07_CRS      := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C08_SATT     := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C09_FIX      := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C10_DIST     := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C11_PWR_VOLT := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C12_IO       := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C13_ALERT_ID := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C14_H_METER  := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C15_BCK_VOLT := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_ALT.C16_MSG_TYPE := LimpaInteiroStr(Strproc);

      SqlTracking := SqlTracking + ' Values(';
      SqlTracking := SqlTracking + QUOTEDSTR(Suntech_Comum.DeviceID) + ',';     //ID
      SqlTracking := SqlTracking + 'DATE_SUB(' + QUOTEDSTR(LimpaDataSuntec(Suntech_ALT.C01_DATE,Suntech_ALT.C02_TIME)) +
                                             ',INTERVAL  hour(timediff(now(),utc_timestamp())) Hour),'; //DH_GPS
      SqlTracking := SqlTracking + Suntech_ALT.C04_LAT + ',';                   //LATITUDE
      SqlTracking := SqlTracking + Suntech_ALT.C05_LON + ',';                   //LONGITUDE
      SqlTracking := SqlTracking + Suntech_ALT.C06_SPD + ',';                   //VELOCIDADE
      SqlTracking := SqlTracking + Suntech_ALT.C10_DIST + ',';                  //ODOMETRO
      SqlTracking := SqlTracking + Suntech_ALT.C07_CRS + ',';                   //ANGULO
      SqlTracking := SqlTracking + Suntech_ALT.C08_SATT + ',';                  //QTDADE_SATELITE
      SqlTracking := SqlTracking + Suntech_ALT.C09_FIX + ',';                   //ATUALIZAD
      SqlTracking := SqlTracking + Suntech_ALT.C11_PWR_VOLT + ',';              //TENSAO
      SqlTracking := SqlTracking + Copy(Suntech_ALT.C12_IO,1,1) + ',';          //CHAVE
      SqlTracking := SqlTracking + Copy(Suntech_ALT.C12_IO,2,1) + ',';          //AUX1
      SqlTracking := SqlTracking + Copy(Suntech_ALT.C12_IO,3,1) + ',';          //AUX2
      SqlTracking := SqlTracking + Copy(Suntech_ALT.C12_IO,4,1) + ',';          //AUX3
      SqlTracking := SqlTracking + Copy(Suntech_ALT.C12_IO,5,1) + ',';          //SAI_1
      SqlTracking := SqlTracking + Copy(Suntech_ALT.C12_IO,6,1) + ',';          //SAI_2
      SqlTracking := SqlTracking + LimpaInteiroStr(Suntech_ALT.C13_ALERT_ID) + ',';  //BREAKDOWN1
      if Suntech_ALT.C13_ALERT_ID = '41'  then                                  //BATERIA_VIOLADA
         SqlTracking := SqlTracking +  '1,'
      Else
         SqlTracking := SqlTracking +  '0,';

      if Suntech_ALT.C13_ALERT_ID = '40'  then                                  //BATERIA_RELIGADA
         SqlTracking := SqlTracking +  '1,'
      Else
         SqlTracking := SqlTracking +  '0,' ;

      SqlTracking := SqlTracking + inttoStr(PortaLocal) + ',';                  //PORTA
      SqlTracking := SqlTracking + QUOTEDSTR(Processar.FieldByName('IP').AsString) + ',';  //IP_REMOTO
      SqlTracking := SqlTracking + Processar.FieldByName('Porta').AsString + ',';  //PORTA_REMOTO
      SqlTracking := SqlTracking + Marc_codigo;

      SqlTracking := SqlTracking + ');' ;                                       //MARC_CODIGO

      SqlAlerta   := SqlAlerta +  ' Values(';
      SqlAlerta   := SqlAlerta + QUOTEDSTR(Suntech_Comum.DeviceID) + ',';     //ID
      SqlAlerta   := SqlAlerta + 'DATE_SUB(' + QUOTEDSTR(LimpaDataSuntec(Suntech_ALT.C01_DATE,Suntech_ALT.C02_TIME)) +
                                             ',INTERVAL  hour(timediff(now(),utc_timestamp())) Hour),'; //DH_GPS
      SqlAlerta   := SqlAlerta + QuotedStr('SA200ALT') + ',';
      SqlAlerta   := SqlAlerta + Suntech_ALT.C13_ALERT_ID + ');';  //Codigo Alerta

//      SalvaLog(Arq_Log, 'Alerta recebido: ' + Suntech_ALT.C13_ALERT_ID + ' - ' +  Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);

      Result := SqlTracking + Chr(13) + Char(10) + SqlAlerta;
   Except
      Result := '';
      SalvaLog(Arq_Log, 'Erro ao executar decode ALT:' + Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);
   End;
End;


//SA200EMG - Emergency Report
Function Gravacao_ET06.Decode_EMG(pPacket: String): String;
Var
   Strproc:     String;
   SqlTracking: String;
   SqlAlerta:   String;
   Suntech_EMG: Pack_SunTech_EMG;

Begin
   Result := '';
   SqlTracking:= 'Insert into nexsat.' + db_tablecarga +  '(ID, DH_GPS, LATITUDE, LONGITUDE, VELOCIDADE, ODOMETRO, '
         + 'ANGULO, QTDADE_SATELITE, ATUALIZADO, TENSAO, CHAVE, AUX1, AUX2, AUX3, SAI_1, '
         + 'SAI_2, BATERIA_VIOLADA, BATERIA, BREAKDOWN2, PORTA, IP_REMOTO, PORTA_REMOTO, MARC_CODIGO ) ' ;
   SqlAlerta := 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) ' ;

   Try

      Strproc          := pPacket;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C01_DATE     := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C02_TIME     := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C03_CELL     := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C04_LAT      := LimpaFloatStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C05_LON      := LimpaFloatStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C06_SPD      := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C07_CRS      := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C08_SATT     := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C09_FIX      := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C10_DIST     := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C11_PWR_VOLT := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C12_IO       := Strproc;
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C13_EMG_ID   := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C14_H_METER  := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C15_BCK_VOLT  := LimpaInteiroStr(Strproc);
      StringProcessar(pPacket, Strproc, Separador);
      Suntech_EMG.C16_MSG_TYPE := LimpaInteiroStr(Strproc);

      SqlTracking := SqlTracking + ' Values(';
      SqlTracking := SqlTracking + QUOTEDSTR(Suntech_Comum.DeviceID) + ',';     //ID
      SqlTracking := SqlTracking + 'DATE_SUB(' + QUOTEDSTR(LimpaDataSuntec(Suntech_EMG.C01_DATE,Suntech_EMG.C02_TIME)) +
                                             ',INTERVAL  hour(timediff(now(),utc_timestamp())) Hour),'; //DH_GPS
      SqlTracking := SqlTracking + Suntech_EMG.C04_LAT + ',';                   //LATITUDE
      SqlTracking := SqlTracking + Suntech_EMG.C05_LON + ',';                   //LONGITUDE
      SqlTracking := SqlTracking + Suntech_EMG.C06_SPD + ',';                   //VELOCIDADE
      SqlTracking := SqlTracking + Suntech_EMG.C10_DIST + ',';                  //ODOMETRO
      SqlTracking := SqlTracking + Suntech_EMG.C07_CRS + ',';                   //ANGULO
      SqlTracking := SqlTracking + Suntech_EMG.C08_SATT + ',';                  //QTDADE_SATELITE
      SqlTracking := SqlTracking + Suntech_EMG.C09_FIX + ',';                   //ATUALIZADO
      SqlTracking := SqlTracking + Suntech_EMG.C11_PWR_VOLT + ',';              //TENSAO
      SqlTracking := SqlTracking + Copy(Suntech_EMG.C12_IO,1,1) + ',';          //CHAVE
      SqlTracking := SqlTracking + Copy(Suntech_EMG.C12_IO,2,1) + ',';          //AUX1
      SqlTracking := SqlTracking + Copy(Suntech_EMG.C12_IO,3,1) + ',';          //AUX2
      SqlTracking := SqlTracking + Copy(Suntech_EMG.C12_IO,4,1) + ',';          //AUX3
      SqlTracking := SqlTracking + Copy(Suntech_EMG.C12_IO,5,1) + ',';          //SAI_1
      SqlTracking := SqlTracking + Copy(Suntech_EMG.C12_IO,6,1) + ',';          //SAI_2
      if ParaInteiro(Suntech_EMG.C13_EMG_ID) = 3 then                             //BATERIA_VIOLADA, BATERIA,
      Begin
         if (Debug_id = Suntech_Comum.DeviceID) then
            SalvaLog(Arq_Log, 'Bateria Violada: ' +  Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);

         SqlTracking := SqlTracking + '1,';
         SqlTracking := SqlTracking + '1,';
      End
      Else
      Begin
         if (Debug_id = Suntech_Comum.DeviceID) then
            SalvaLog(Arq_Log, 'Outras Emerg?ncias: ' + Suntech_EMG.C13_EMG_ID + ' - ' + Suntech_comum.DeviceID + '/' +  Processar.FieldByName('DataGrama').AsString);

         SqlTracking := SqlTracking + '0,';
         SqlTracking := SqlTracking + '0,';
      End;

      SqlTracking := SqlTracking + LimpaInteiroStr(Suntech_EMG.C13_EMG_ID)+ ',';//BREAKDOWN2
      SqlTracking := SqlTracking + inttoStr(PortaLocal) + ',';                  //PORTA
      SqlTracking := SqlTracking + QUOTEDSTR(Processar.FieldByName('IP').AsString) + ',';  //IP_REMOTO
      SqlTracking := SqlTracking + Processar.FieldByName('Porta').AsString + ',';  //PORTA_REMOTO
      SqlTracking := SqlTracking + marc_codigo;                                 //MARC_CODIGO

      SqlTracking := SqlTracking + ');' ;

      SqlAlerta   := SqlAlerta +  ' Values(';
      SqlAlerta   := SqlAlerta + QUOTEDSTR(Suntech_Comum.DeviceID) + ',';     //ID
      SqlAlerta   := SqlAlerta + 'DATE_SUB(' + QUOTEDSTR(LimpaDataSuntec(Suntech_EMG.C01_DATE,Suntech_EMG.C02_TIME)) +
                                             ',INTERVAL  hour(timediff(now(),utc_timestamp())) Hour),'; //DH_GPS
      SqlAlerta   := SqlAlerta + QuotedStr('SA200EMG') + ',';
      SqlAlerta   := SqlAlerta + Suntech_EMG.C13_EMG_ID + ');';  //Codigo Alerta

//      SalvaLog(Arq_Log, 'Alerta recebido: ' + Suntech_ALT.C13_ALERT_ID + ' - ' +  Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);

      Result := SqlTracking + Chr(13) + Char(10) + SqlAlerta;
   Except
      Result := '';
      SalvaLog(Arq_Log, 'Erro ao executar decode EMG:' + Suntech_comum.DeviceID + '/' +  Processar.FieldByName('DataGrama').AsString);
   End;
End;

//SA200CMD - Control Command
Function Gravacao_ET06.Decode_CMD(pPacket: String): String;
Var
   PosInicio: Integer;
   PosFinal:  Integer;
   Strproc:   String;
   TipoCmd:   String;
   Track_NTW: String;
   Track_RPT: String;
   Track_EVT: String;
   Track_GSM: String;
   Track_SVC: String;
   Track_DEV: String;

Begin
   Result := '';

   Try



      if (Pos('Preset', pPacket) > 0 ) then
      Begin

         Strproc                  := pPacket;
         StringProcessar(pPacket, Strproc, Separador);
         TipoCmd                  := Trim(Strproc);

         if Debug in [2, 5, 9] then
            SalvaLog(Arq_Log, 'Decode CMD-SubTipo: Preset');

         //Copia Pacote  NTW
         PosInicio := Pos('NTW;',pPacket);
         PosFinal  := Pos('RPT;',pPacket);
         if ((PosInicio <> 0) and (PosFinal <> 0)) or ((PosInicio > 0) and  (PosInicio < Length(pPacket)))  then
         Begin
            Track_NTW := Copy(pPacket, PosInicio+4,(PosFinal - PosInicio-4));
            Result    := Result + Decode_Generico(Track_NTW,'NTW',SunTech_NTW);
         End;

         //Copia Pacote  RPT
         PosInicio := Pos('RPT;',pPacket);
         PosFinal  := Pos('EVT;',pPacket);
         if (PosInicio <> 0) and (PosFinal <> 0) or ((PosInicio > 0) and  (PosInicio < Length(pPacket)))  then
         Begin
            Track_RPT := Copy(pPacket, PosInicio+4,(PosFinal - PosInicio-4));
            Result    := Result + Decode_Generico(Track_RPT,'RPT',SunTech_RPT);
         End;

         //Copia Pacote  EVT
         PosInicio := Pos('EVT;',pPacket);
         PosFinal  := Pos('GSM;',pPacket);
         if (PosInicio <> 0) and (PosFinal <> 0) or ((PosInicio > 0) and  (PosInicio < Length(pPacket)))  then
         Begin
            Track_EVT := Copy(pPacket, PosInicio+4,(PosFinal - PosInicio-4));
            Result    := Result + Decode_Generico(Track_EVT,'EVT',SunTech_EVT);
         End;

         //Copia Pacote  GSM
         PosInicio := Pos('GSM;',pPacket);
         PosFinal  := Pos('SVC;',pPacket);
         if (PosInicio <> 0) and (PosFinal <> 0) or ((PosInicio > 0) and  (PosInicio < Length(pPacket)))  then
         Begin
            Track_GSM := Copy(pPacket, PosInicio+4,(PosFinal - PosInicio-4));
            Result    := Result + Decode_Generico(Track_GSM,'GSM',SunTech_GSM);
         End;

         //Copia Pacote  SVC
         PosInicio := Pos('SVC;',pPacket);
         PosFinal  := Pos('DEV;',pPacket);
         if (PosInicio <> 0) and (PosFinal <> 0) or ((PosInicio > 0) and  (PosInicio < Length(pPacket)))  then
         Begin
            Track_SVC := Copy(pPacket, PosInicio+4,(PosFinal - PosInicio-4));
            Result    := Result + Decode_Generico(Track_SVC,'SVC',SunTech_SVC);
         End;

         //Copia Pacote  DEV
         PosInicio := Pos('DEV;',pPacket);
         if (PosInicio < Length(pPacket)) then
         Begin
            Track_DEV := Copy(pPacket, PosInicio+4,200);
            Result    := Result + Decode_Generico(Track_DEV,'DEV',SunTech_DEV);
         End;

         if Debug in [2, 5, 9] then
            SalvaLog(Arq_Log, 'Decode CMD:' + Result);

      End
      Else if (Pos('AckEmerg', pPacket) > 0 ) then
      Begin
         if Debug in [2, 5, 9] then
            SalvaLog(Arq_Log, 'Decode CMD-SubTipo: AckEmerg');

         Strproc                  := pPacket;
         StringProcessar(pPacket, Strproc, Separador);
         TipoCmd                  := Trim(Strproc);

         Result                   := 'Replace into nexsat.dispositivos_status (ID, PARAM, VALOR, DT_ULTIMA, ENVI_REMOTO) Values(';
         Result                   := Result + QuotedStr(Suntech_comum.DeviceID) + ',';
         Result                   := Result + QuotedStr(TipoCmd) + ',';
         Result                   := Result + QuotedStr(Suntech_comum.Versao) + ',' ;
         Result                   := Result + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', now())) + ',0);' + Char(13) + Char(10);

      End
      Else
         SalvaLog(Arq_Log, 'SubTipo n?o Previsto - ID/CMD:' + Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);

   Except
      Result := '';
      SalvaLog(Arq_Log, 'Erro ao executar decode GENERICO:' + Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);
   End;
End;



Function Gravacao_ET06.Decode_Generico(pPacket,pTipo: String; pVetor: Array Of String ): String;
Var
   Strproc:    String;
   SqlParam:   String;
   SqlRetorno: String;
   Contador:   Integer;
Begin

   Result     := '';
   SqlRetorno := '';
   SqlParam   := 'Replace into nexsat.dispositivos_status (ID, PARAM, VALOR, DT_ULTIMA, ENVI_REMOTO) Values(';

   Try

      Strproc          := pPacket;
      //Pacote NetWork tem 10 posicoes
      for Contador := 0 to Length(pVetor)-1 do
      Begin
         StringProcessar(pPacket, Strproc, Separador);
         if Strproc <> '' then
         Begin
            SqlRetorno := SqlRetorno + SqlParam + QuotedStr(Suntech_comum.DeviceID) + ',';
            SqlRetorno := SqlRetorno + QuotedStr(pTipo + '_' + pVetor[Contador]) + ',';
            SqlRetorno := SqlRetorno + QuotedStr(Trim(Strproc)) + ',' ;
            SqlRetorno := SqlRetorno + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss', now())) + ',0);' + Char(13) + Char(10);
         End;
      End;

      Result := SqlRetorno;

   Except
      Result := '';
      SalvaLog(Arq_Log, 'Erro ao executar decode Generico:' + pTipo + '/' +  Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);
   End;
End;


Procedure Gravacao_ET06.LimpaRecord();
Begin

   Suntech_comum.HDR        := '';
   Suntech_comum.DeviceID   := '';
   Suntech_comum.Versao     := '';
   Suntech_comum.Resposta   := '';

End;

Procedure Gravacao_ET06.Dormir(pTempo: Word);
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



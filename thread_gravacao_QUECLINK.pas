unit thread_gravacao_QUECLINK;

interface

uses
   Windows, SysUtils, Classes, Math, StrUtils, //ZConnection,
   DB, DBClient, DateUtils, //ZDataset, ZAbstractRODataset,
   //ZStoredProcedure,
   FuncColetor, FunQUECLINK;
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

   Gravacao_QUECLINK = class(TThread)
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
      Debug_pct: String;
      PortaLocal: Integer;
      Encerrar: Boolean;
      Debug: SmallInt;
      ThreadId: Word;
      Separador: String;
      gravatemp : string;
      contador_arquivo : Integer;
      quant_sql : Integer;
      Suntech_Header: Pack_SunTech;

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
      Function  Decode_STT(pPacket: String; vPacket: String): String;
      Function  Decode_ALT(pPacket: String): String;
      Function  Decode_EMG(pPacket: String): String;
      Function  Decode_CMD(pPacket: String): String;
      Function  Decode_Generico(pPacket,pTipo: String; pVetor: Array Of String ): String;
      Function  HexToAscii(Hex: String): String;
      Function  HexToStrBitsInverted_f(pHex: String; pZeroToUm: boolean): String;

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure Gravacao_QUECLINK.Execute;
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

         TcpSrvForm.ThGravacao_QUECLINK_ultimo := Now;

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

Procedure Gravacao_QUECLINK.BuscaArquivo;
Var
   Arquivos: TSearchRec;
Begin
   Try
      ArqPendentes := 0;
      Arq_inbox := '';

      if FindFirst(DirInbox + '\*.QUE*' + FormatFloat('00', ThreadId), faArchive,
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

Procedure Gravacao_QUECLINK.GravaDatabase;
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

Function Gravacao_QUECLINK.Decode(pPacket: String): String;
Var
   Strproc,NovoPacket:   String;
   SqlTracking: String;
   contador,BytesTot : integer;
Begin
   Result := '';
   Try
      pct_inteiro    := pPacket;
      Suntech_Comum.pacote_inteiro := pct_inteiro;
      LimpaRecord;
      for Contador := 0 to 4 - 1 do
        begin
          StringProcessar(pct_inteiro, Strproc, Separador);
          NovoPacket := NovoPacket + HexToAscii(Strproc);
          if Contador <= 3 then
            Suntech_Header.HDR := NovoPacket;
        end;
      Suntech_comum.HDR      := Suntech_Header.HDR;
      StringProcessar(pct_inteiro, Strproc, Separador);
      Suntech_comum.tipo := HexToNumber(Strproc);
      Suntech_comum.configuracao := '';
      Suntech_comum.lengt := '';
      Suntech_comum.Versao := '';
      Suntech_comum.Firmware := '';
      Suntech_comum.DeviceID := '';
      for Contador := 0 to 4 - 1 do
        begin
          StringProcessar(pct_inteiro, Strproc, Separador);
          Suntech_comum.configuracao := Suntech_comum.configuracao + Strproc;
        end;
      for Contador := 0 to 2 - 1 do
        begin
          StringProcessar(pct_inteiro, Strproc, Separador);
          Suntech_comum.lengt := Suntech_comum.lengt + Strproc;
        end;
      Suntech_comum.lengt := HexToNumber(Suntech_comum.lengt);
      StringProcessar(pct_inteiro, Strproc, Separador);
      Suntech_comum.DeviceType := HexToNumber(Strproc);
      for Contador := 0 to 2 - 1 do
        begin
          StringProcessar(pct_inteiro, Strproc, Separador);
          Suntech_comum.Versao := Suntech_comum.Versao + HexToNumber(Strproc);
        end;
      for Contador := 0 to 2 - 1 do
        begin
          StringProcessar(pct_inteiro, Strproc, Separador);
          Suntech_comum.Firmware := Suntech_comum.Firmware + HexToNumber(Strproc);
        end;
      for Contador := 0 to 8 - 1 do
        begin
          StringProcessar(pct_inteiro, Strproc, Separador);
          if Contador = 7 then
            Suntech_comum.DeviceID := Suntech_comum.DeviceID + HexToNumber(Strproc)
          else
            Suntech_comum.DeviceID := Suntech_comum.DeviceID + StrZero(HexToNumber(Strproc),2);
        end;


      //Truque sujo !!!!
      pPacket := pPacket + ',';

      if (Suntech_comum.HDR = '+BSP') or (Suntech_comum.HDR = '+RSP') or (Suntech_comum.HDR = '+EVT') or (Suntech_comum.HDR = '+BVT') Then    //SA200STT - Status Report
         SqlTracking := Decode_STT(pct_inteiro,pPacket)
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
Function Gravacao_QUECLINK.Decode_STT(pPacket: String; vPacket: String): String;
Var
   Strproc,vtensao,sinal:   String;
   SqlTracking,SqlTracking1, var_bat_interna,var_bat_externa: String;
   Suntech_STT: Pack_SunTech_STT;
  S1, S2,ip,pact,configuracao,tensao_ext, var_tensao,var_violada,var_desviolada,sequencial: string;
  vdata,nova_dt:TDateTime;
  testedata:TDateTime;
  tempo : Ttime;
  i,w,z : integer;
  Latitude: Double;
  posicao : SmallInt;
  Longitude, calc_tensao_ext: Double;
  calclat,calclon: Array [1 .. 4] of Byte;
  firstbyte : array[1..8] of string;
  secondbyte : array[1..8] of string;
Begin
   Result := '';
   SqlTracking:= 'Insert into nexsat.' + db_tablecarga +  '(ID, DH_GPS, LATITUDE, LONGITUDE, VELOCIDADE, ODOMETRO, '
         + 'ANGULO, QTDADE_SATELITE, TENSAO, HORIMETRO, ATUALIZADO, BATERIA, CHAVE, AUX1, AUX2, AUX3, SAI_1, '
         + 'SAI_2, PORTA, IP_REMOTO, PORTA_REMOTO, MARC_CODIGO, tensao_externa ) ' ;

   Try
// come?o da leitura e grava??o dos pacotes do Quecklink
        SqlTracking1:= 'Insert into nexsat.posicao_tmp(id,pacote,marc_codigo,data_rec) Values(';
        SqlTracking1:= SqlTracking1+QuotedStr(Suntech_Comum.DeviceID)+','+QuotedStr(vPacket)+','+QuotedStr(marc_codigo)+',current_timestamp)' ;
// come?o da leitura do pacote tracker
        pPacket := pct_inteiro;
        if Suntech_Comum.DeviceID = '862193027869874' then
          w := 0;
        if copy(Suntech_comum.configuracao,1,2) = '00' then
          Suntech_comum.configuracao := copy(Suntech_comum.configuracao,3)
        else
          Suntech_comum.configuracao := Suntech_comum.configuracao;

        configuracao := HexToStrBitsInverted_f(Suntech_comum.configuracao,false);
        // Bateria
        var_bat_interna := '0';
        if (Suntech_comum.tipo = '1') or (Suntech_comum.tipo = '2') then
          begin
            Suntech_STT.C18_PWR := '0';
            vtensao := '0';
          end;

        if (strtoint(copy(configuracao,12,1)) = 1) and (Suntech_comum.tipo <> '1') and (Suntech_comum.tipo <> '2') then
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            Suntech_STT.C18_PWR := HexToNumber(Strproc);
            vtensao := Suntech_STT.C18_PWR;
            var_bat_interna := Suntech_STT.C18_PWR;
          end

        else
          begin
       //     Suntech_STT.C18_PWR := '0';
            vtensao := '0';
            if (Suntech_comum.HDR <> '+BVT') then
              if ((Suntech_comum.HDR <> '+EVT') and (strtoint(Suntech_comum.tipo) = 45)) or
                 ((Suntech_comum.HDR <> '+EVT') and (strtoint(Suntech_comum.tipo) = 46)) then
              begin
                StringProcessar(pct_inteiro, Strproc, Separador);
                Suntech_STT.C18_PWR := HexToNumber(Strproc);
                vtensao := Suntech_STT.C18_PWR;
              end
            else if (Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 1) and (strtoint(Suntech_comum.lengt) = 94)  then
              begin
                StringProcessar(pct_inteiro, Strproc, Separador);
                Suntech_STT.C18_PWR := HexToNumber(Strproc);
                vtensao := Suntech_STT.C18_PWR;
              end;
          end;

        vtensao := '0';
        var_violada := '0';
        var_desviolada := '0';
        if (Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 4)  then
          begin
            Suntech_STT.C18_PWR := '1'  ;
            var_violada := '1';
          end
        else if (Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 3)  then
          begin
           Suntech_STT.C18_PWR := '0'  ;
           var_desviolada := '1';
          end
        else
          Suntech_STT.C18_PWR := '';
        if strtoint(copy(configuracao,13,1)) = 1 then
          begin
            calc_tensao_ext := 0;
            var_tensao := '0';
            var_bat_externa := '0';
            Suntech_STT.C18_PWR := '0';
            StringProcessar(pct_inteiro, Strproc, Separador);
            if (Suntech_comum.HDR = '+RSP') and (strtoint(Suntech_comum.tipo) = 1) and (strtoint(Suntech_comum.lengt) = 97) then
              begin
                Suntech_STT.C18_PWR := HexToNumber(Strproc);
                var_bat_interna := Suntech_STT.C18_PWR;
                if Suntech_STT.C18_PWR = '100' then
                   Suntech_STT.C18_PWR := '0'
                 else
                   Suntech_STT.C18_PWR := '1';
                vtensao := Suntech_STT.C18_PWR;
                StringProcessar(pct_inteiro, Strproc, Separador);   //tensao externa (var_tensao)
                tensao_ext := Strproc;
                StringProcessar(pct_inteiro, Strproc, Separador);   //tensao externa (var_tensao)
                tensao_ext := tensao_ext + Strproc;
                tensao_ext := HexToNumber(tensao_ext);
                calc_tensao_ext := strtoint(tensao_ext)/1000;
                vtensao := inttostr(round(calc_tensao_ext));
              end
            else
              begin
                tensao_ext := Strproc;
                var_tensao := Strproc;
                StringProcessar(pct_inteiro, Strproc, Separador);   //tensao externa (var_tensao)
                tensao_ext := tensao_ext + Strproc;
                tensao_ext := HexToNumber(tensao_ext);
                calc_tensao_ext := strtoint(tensao_ext)/1000;
                vtensao := inttostr(round(calc_tensao_ext));
              end;
            if (var_violada = '1') and (Suntech_comum.HDR = '+EVT') then
              begin
                var_bat_interna := '0';
                var_bat_interna := FloatToStr(calc_tensao_ext);
              end
            else
              var_bat_externa := FloatToStr(calc_tensao_ext);
//            if calc_tensao_ext < 5 then
//              Suntech_STT.C18_PWR := '1';
          end;
        // chave
        StringProcessar(pct_inteiro, Strproc, Separador);
        Suntech_STT.C12_IO := copy(HexToStrBitsInverted_f(Strproc,false),1,1);

        if strtoint(copy(configuracao,18,1)) = 1 then
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            Suntech_STT.C21_SAI1 := copy(HexToStrBitsInverted_f(Strproc,false),1,1);
            Suntech_STT.C23_AUX1 := copy(HexToStrBitsInverted_f(Strproc,false),2,1);
            Suntech_STT.C24_AUX2 := copy(HexToStrBitsInverted_f(Strproc,false),3,1);
            Suntech_STT.C25_AUX3 := copy(HexToStrBitsInverted_f(Strproc,false),4,1);
            StringProcessar(pct_inteiro, Strproc, Separador);
//            Suntech_STT.C12_IO := copy(HexToStrBitsInverted_f(Strproc,false),1,1);
          end
        else
          begin
            Suntech_STT.C23_AUX1 := '0';
            Suntech_STT.C24_AUX2 := '0';
            Suntech_STT.C25_AUX3 := '0';
            Suntech_STT.C21_SAI1 := '0';
          end;
        //satelite
        if strtoint(copy(configuracao,20,1)) = 1 then
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            Suntech_STT.C08_SATT := HexToNumber(Strproc);
          end
        else
            Suntech_STT.C08_SATT := '0';
        if ((Suntech_comum.tipo <> '1') and (Suntech_comum.tipo <> '2'))
            or ((Suntech_comum.HDR = '+RSP') and (strtoint(Suntech_comum.tipo) = 1))
            or ((Suntech_comum.HDR = '+RSP') and (strtoint(Suntech_comum.tipo) = 2))then
          StringProcessar(pct_inteiro, Strproc, Separador);
        StringProcessar(pct_inteiro, Strproc, Separador);
        StringProcessar(pct_inteiro, Strproc, Separador);

        if strtoint(HexToNumber(Strproc)) < 7 then
          valid := '1'
        else
          valid := '0';
        if ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 14))
            or ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 13))
            or ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 45))
            or ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 46))
            or ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 45))
            or ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 46)) then
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
            if ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 45))
               or ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 46))
               or ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 45))
               or ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 46)) then
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  StringProcessar(pct_inteiro, Strproc, Separador);
                end;
          end;
        if ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 14))
            or ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 13)) then
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
          end;
        //speed velocidade
        if strtoint(copy(configuracao,1,1)) = 1 then
          begin
            if (Suntech_comum.HDR = '+RSP') and (strtoint(Suntech_comum.tipo) = 1) and (strtoint(Suntech_comum.lengt) = 97) then
              for i := 0 to 3 - 1 do
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  Suntech_STT.C06_SPD := Suntech_STT.C06_SPD + Strproc;
                end
            else
              for i := 0 to 2 - 1 do
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  Suntech_STT.C06_SPD := Suntech_STT.C06_SPD + Strproc;
                end ;
            Suntech_STT.C06_SPD := HexToNumber(Suntech_STT.C06_SPD);
            if (Suntech_comum.HDR <> '+RSP') and (strtoint(Suntech_comum.tipo) <> 1) and (strtoint(Suntech_comum.lengt) <> 97) then
              StringProcessar(pct_inteiro, Strproc, Separador);
          end
        else
          Suntech_STT.C06_SPD := '0';
        //angulo azimuth
        if strtoint(copy(configuracao,2,1)) = 1 then
          for i := 0 to 2 - 1 do
            begin
              StringProcessar(pct_inteiro, Strproc, Separador);
              Suntech_STT.C07_CRS := Suntech_STT.C07_CRS + HexToNumber(Strproc);
            end
        else
          Suntech_STT.C07_CRS := '0';
        //Altitude nao gravar
        if strtoint(copy(configuracao,3,1)) = 1 then
            begin
              StringProcessar(pct_inteiro, Strproc, Separador);
              if ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 45))
                 or ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 46))
                 or ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 1))
                 or ((Suntech_comum.HDR = '+EVT') and (strtoint(Suntech_comum.tipo) = 2))
                 or ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 45))
                 or ((Suntech_comum.HDR = '+BVT') and (strtoint(Suntech_comum.tipo) = 46))
                 or (Suntech_comum.HDR = '+BSP') or (Suntech_comum.HDR = '+RSP') then
                 StringProcessar(pct_inteiro, Strproc, Separador);
            end ;
        // Longitude
        for i := 0 to 4 - 1 do
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            Suntech_STT.C05_LON := Suntech_STT.C05_LON + Strproc;
          end ;
        Suntech_STT.C05_LON := IntToHex(hexatoint(Suntech_STT.C05_LON) * -1 ,4);
        Suntech_STT.C05_LON := '-' + floattostr((hexatoint(copy(Suntech_STT.C05_LON,length(Suntech_STT.C05_LON)- 7,8)) / 1000000));
        Suntech_STT.C05_LON := troca(Suntech_STT.C05_LON);
        // Latitude
        for i := 0 to 4 - 1 do
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            Suntech_STT.C04_LAT := Suntech_STT.C04_LAT + Strproc;
          end ;
        Suntech_STT.C04_LAT := IntToHex(hexatoint(Suntech_STT.C04_LAT) * -1 ,4);
        Suntech_STT.C04_LAT := '-' + floattostr((hexatoint(copy(Suntech_STT.C04_LAT,length(Suntech_STT.C04_LAT)- 7,8)) / 1000000));
        Suntech_STT.C04_LAT := troca(Suntech_STT.C04_LAT);
        // DHGPS
        for i := 0 to 7 - 1 do
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            Suntech_STT.C01_DATE := Suntech_STT.C01_DATE + Strproc;
          end ;
        Suntech_STT.C02_TIME := copy(Suntech_STT.C01_DATE,length(Suntech_STT.C01_DATE)-5,6) ;
        Suntech_STT.C02_TIME := strzero(HexToNumber(copy(Suntech_STT.C02_TIME,1,2)),2) + ':' + StrZero(HexToNumber(copy(Suntech_STT.C02_TIME,3,2)),2) + ':' + StrZero(HexToNumber(copy(Suntech_STT.C02_TIME,5,2)),2);
        Suntech_STT.C01_DATE := HexToNumber(copy(Suntech_STT.C01_DATE,1,4)) + StrZero(HexToNumber(copy(Suntech_STT.C01_DATE,5,2)),2) + StrZero(HexToNumber(copy(Suntech_STT.C01_DATE,7,2)),2);
        // MCC/MNC/LAC/CELL ID
        if strtoint(copy(configuracao,4,1)) = 1 then
          begin
            for i := 0 to 2 - 1 do
              begin
                StringProcessar(pct_inteiro, Strproc, Separador);
                Suntech_STT.C26_MCC := Suntech_STT.C26_MCC + HexToNumber(Strproc);
              end;
            for i := 0 to 2 - 1 do
              begin
                StringProcessar(pct_inteiro, Strproc, Separador);
                Suntech_STT.C27_MNC := Suntech_STT.C27_MNC + HexToNumber(Strproc);
              end ;
            for i := 0 to 2 - 1 do
              begin
                StringProcessar(pct_inteiro, Strproc, Separador);
                Suntech_STT.C28_LAC := Suntech_STT.C28_LAC + HexToNumber(Strproc);
              end ;
            for i := 0 to 2 - 1 do
              begin
                StringProcessar(pct_inteiro, Strproc, Separador);
                Suntech_STT.C03_CELL := Suntech_STT.C03_CELL + HexToNumber(Strproc);
              end
          end
        else
          Begin
            Suntech_STT.C26_MCC := '0';
            Suntech_STT.C27_MNC := '0';
            Suntech_STT.C28_LAC := '0';
            Suntech_STT.C03_CELL := '0';
          End;
        StringProcessar(pct_inteiro, Strproc, Separador);
        if strtoint(copy(configuracao,21,1)) = 1 then
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
          end;
        if strtoint(copy(configuracao,22,1)) = 1 then
          begin
            if (Suntech_comum.HDR = '+RSP') and (strtoint(Suntech_comum.tipo) = 1) and (strtoint(Suntech_comum.lengt) = 97) then
              for i := 0 to 5 - 1 do
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  Suntech_STT.C09_FIX := Suntech_STT.C09_FIX + Strproc;
                end
            else
              for i := 0 to 4 - 1 do
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  Suntech_STT.C09_FIX := Suntech_STT.C09_FIX + Strproc;
                end;
            Suntech_STT.C09_FIX := HexToNumber(Suntech_STT.C09_FIX);
//            StringProcessar(pct_inteiro, Strproc, Separador);
          end
        else
          Suntech_STT.C09_FIX := '0';

        if strtoint(copy(configuracao,23,1)) = 1 then
          begin
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
            StringProcessar(pct_inteiro, Strproc, Separador);
          end;
        if strtoint(copy(configuracao,24,1)) = 1 then
          for i := 0 to 6 - 1 do
            begin
              StringProcessar(pct_inteiro, Strproc, Separador);
              Suntech_STT.C15_H_METER := Suntech_STT.C15_H_METER + HexToNumber(Strproc);
            end;
        if 2147483647 < StrToInt64(Suntech_STT.C15_H_METER)  then
           Suntech_STT.C15_H_METER := '0';
        if strtoint(copy(configuracao,5,1)) = 1 then
          if (Suntech_comum.HDR = '+RSP') and (strtoint(Suntech_comum.tipo) = 1) and (strtoint(Suntech_comum.lengt) = 97) then
            begin
              StringProcessar(pct_inteiro, Strproc, Separador);
              StringProcessar(pct_inteiro, Strproc, Separador);
              for i := 0 to 7 - 1 do
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  Suntech_STT.C02_TIME1 := Suntech_STT.C02_TIME1 + Strproc;
                end;
            end
          else
              for i := 0 to 7 - 1 do
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  Suntech_STT.C02_TIME1 := Suntech_STT.C02_TIME1 + Strproc;
                end ;
          sequencial := '0';
          if (Suntech_comum.HDR = '+RSP') and (strtoint(Suntech_comum.tipo) = 1) and (strtoint(Suntech_comum.lengt) = 97) then
            begin
              for i := 0 to 2 - 1 do
                begin
                  StringProcessar(pct_inteiro, Strproc, Separador);
                  sequencial := sequencial + Strproc;
                end ;
              sequencial := HexToNumber(sequencial);
            end;

         Suntech_STT.C22_VEL_EX := '0';
// fim do pacote
        //montagem do insert na tabela posicoes carga
        if tensao_ext = '' then
          tensao_ext:= '0';
        if var_bat_externa = '' then
           var_bat_externa:= '0';
        SqlTracking:= 'Insert into ' + db_database + '.' + db_tablecarga +'(ID, DH_GPS, LATITUDE, LONGITUDE, VELOCIDADE, ODOMETRO, '
           + 'ANGULO, QTDADE_SATELITE, TENSAO, HORIMETRO, ATUALIZADO, BATERIA, CHAVE, AUX1, AUX2, AUX3, SAI_1, '
           + 'SAI_2, PORTA, IP_REMOTO, PORTA_REMOTO, MARC_CODIGO, DATA_REC, VEL_EXCESS, tensao_externa, bateria_violada, bateria_religada, tensao_interna, versao, produto, tipo_pacote, tipo_pacote_original,pacote,SEQ_MSG ) ' ;
        SqlTracking := SqlTracking + ' Values(';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_Comum.DeviceID) + ',';     //ID
        SqlTracking := SqlTracking + 'DATE_SUB(' + QUOTEDSTR(LimpaDataSuntec(Suntech_STT.C01_DATE,Suntech_STT.C02_TIME)) +
                                             ',INTERVAL  hour(timediff(now(),utc_timestamp())) Hour),'; //DH_GPS
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C04_LAT) + ',';                   //LATITUDE
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C05_LON) + ',';                   //LONGITUDE
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C06_SPD) + ',';                   //VELOCIDADE
        SqlTracking := SqlTracking + ' if('+QUOTEDSTR(Suntech_STT.C09_FIX)+'= ''0'',null,'+QUOTEDSTR(Suntech_STT.C09_FIX)+ '),';                  //ODOMETRO
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C07_CRS) + ',';                   //ANGULO
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C08_SATT) + ',';                  //QTDADE_SATELITE  /
        SqlTracking := SqlTracking + QUOTEDSTR(vtensao) + ',' + QUOTEDSTR(Suntech_STT.C15_H_METER) + ',';  //tensao  /  Horimetro
        SqlTracking := SqlTracking + QUOTEDSTR(valid)+ ','  ;                                     //ATUALIZAD
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C18_PWR) + ',';              //TENSAO / Bateria STT.
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C12_IO) + ',' + QUOTEDSTR(Suntech_STT.C23_AUX1) + ',' + QUOTEDSTR(Suntech_STT.C24_AUX2) + ',' + QUOTEDSTR(Suntech_STT.C25_AUX3) + ',';          //CHAVE saidas 1 2 3
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C21_SAI1) + ','+ QUOTEDSTR(Suntech_STT.C24_AUX2) + ',';                   //said 1
        SqlTracking := SqlTracking + QUOTEDSTR(inttoStr(PortaLocal)) + ',';          //porta
        SqlTracking := SqlTracking + QUOTEDSTR(Processar.FieldByName('IP').AsString) + ',';  //IP_REMOTO
        SqlTracking := SqlTracking + Processar.FieldByName('Porta').AsString + ',';  //PORTA_REMOTO
        SqlTracking := SqlTracking + QuotedStr(marc_codigo) + ',CURRENT_TIMESTAMP' + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_STT.C22_VEL_EX) + ','+  StringReplace(var_bat_externa, ',', '.', [rfIgnoreCase])  + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(var_violada) + ',';
        SqlTracking := SqlTracking + var_desviolada + ',' + StringReplace(var_bat_interna, ',', '.', [rfIgnoreCase]) + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_Comum.Versao) + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_Comum.Firmware) + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_comum.tipo) + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_comum.HDR) + ',';
        SqlTracking := SqlTracking + QUOTEDSTR(Suntech_comum.pacote_inteiro) + ',' + QUOTEDSTR(sequencial) + ')';


        //StringReplace(FloatToStr(calc_tensao_ext), ',', '.', [rfIgnoreCase]) + ')';    //veloc.Excess
//        Suntech_STT.C01_DATE := '38410907';
        if (TryStrToDate((copy(Suntech_STT.C01_DATE,7,2)+'/'+
          copy(Suntech_STT.C01_DATE,5,2)+'/'+
          copy(Suntech_STT.C01_DATE,1,4)),testedata)) and (StrToDate((copy(Suntech_STT.C01_DATE,7,2)+'/'+
          copy(Suntech_STT.C01_DATE,5,2)+'/'+
          copy(Suntech_STT.C01_DATE,1,4))) < incHour(now,3)) then
          begin
            Result := SqlTracking + ';';
          end
        else
          begin
            SalvaLog(Arq_Log, 'Erro ao executar decode STT:' + Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);
            SalvaLog(Arq_Log, 'Erro Insert :' + Suntech_comum.DeviceID + '/' + SqlTracking);
          end;

       if (Debug in [2, 5, 9]) then
         SalvaLog(Arq_Log, 'ID :' + Suntech_comum.DeviceID + ' Cabe?alho :' + Suntech_comum.HDR + ' Tipo pacote :' + Suntech_comum.tipo + ' Tensao Externa :' + var_bat_externa + ' Tensao Interna :' + var_bat_interna + ' Bateria Violada :' + var_violada + ' Bateria Religada :' + var_desviolada );

   Except
      Result := '';
      SalvaLog(Arq_Log, 'Erro ao executar decode STT:' + Suntech_comum.DeviceID + '/' + Processar.FieldByName('DataGrama').AsString);
   End;
End;

//SA200ALT - Alert Report
Function Gravacao_QUECLINK.Decode_ALT(pPacket: String): String;
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
Function Gravacao_QUECLINK.Decode_EMG(pPacket: String): String;
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
Function Gravacao_QUECLINK.Decode_CMD(pPacket: String): String;
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



Function Gravacao_QUECLINK.Decode_Generico(pPacket,pTipo: String; pVetor: Array Of String ): String;
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


Procedure Gravacao_QUECLINK.LimpaRecord();
Begin

   Suntech_comum.HDR        := '';
   Suntech_comum.DeviceID   := '';
   Suntech_comum.Versao     := '';
   Suntech_comum.Resposta   := '';

End;

Procedure Gravacao_QUECLINK.Dormir(pTempo: Word);
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

Function Gravacao_QUECLINK.HexToAscii(Hex: String): String;
begin
   result := chr(StrToInt('$'+hex));
end;

Function Gravacao_QUECLINK.HexToStrBitsInverted_f(pHex: String; pZeroToUm: boolean): String;
Var
   NumTmp: Integer;
   Contador: ShortInt;
   lZero: String;
   lUm: String;
begin

   if pZeroToUm then
   Begin
      lZero := '1';
      lUm := '0';
   End
   Else
   Begin
      lZero := '0';
      lUm := '1';
   End;

   NumTmp := StrToIntDef('$' + pHex,0);

   for Contador := 0 to 23 do
      if (NumTmp and (1 shl Contador)) = 0 then
         Result := Result + lZero
      Else
         Result := Result + lUm;

end;


end.



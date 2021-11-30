unit thread_gravacao_CalAmp;

interface

uses
   Windows, SysUtils, Classes, Math, DB, DBClient, Types,
   DateUtils, FuncColetor, FunCalAmp;

type
   gravacao_CalAmp = class(TThread)

   public

      // Parametros recebidos
      db_inserts: Integer; // Insert Simultaneo
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      db_tablecarga: String; // Nome da tabela de carga
      marc_codigo: String;
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

   private
      { Private declarations }
      SqlTracking: String;
      SqlPendente: String;
      PacketStr: String;
      PacketTot: TByteDynArray;
      Resposta: TByteDynArray;
      PosLimite: Word;
      Corrigido: Word;
      Pack_Header: Pack_CalAmp_Header_TCP;
      Pack_Options: Pack_CalAmp_Options_Header;
      Pack_Message_Header: Pack_CalAmp_Message_Header;
      Pack_Event_Message: Pack_CalAmp_Event_Report_Message;

   protected
      Processar: tClientDataSet;
      Processados: tClientDataSet;
      Dispositivos: tClientDataSet;

      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaTracking;
      Procedure ZeraRecord;
      Procedure Imprime;
      Procedure Dormir(pTempo: Word);
      Function  Decode(pPacket:TByteDynArray): SmallInt;

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure gravacao_CalAmp.Execute;
begin
   Try

      SqlTracking := 'insert into nexsat.' + db_tablecarga + ' ';
      SqlTracking := SqlTracking +
         '(id, dh_gps, latitude, longitude, porta, ip_remoto, porta_remoto, velocidade, angulo, qtdade_satelite, atualizado, chave, bateria_violada, bateria_religada, breakdown1, breakdown2, breakdown3, breakdown4, marc_codigo) ';


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

      Processados := tClientDataSet.Create(nil);
      Processados.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processados.FieldDefs.Add('IP', ftString, 15, False);
      Processados.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processados.FieldDefs.Add('ID', ftString, 20, False);
      Processados.FieldDefs.Add('Resposta', ftBlob, 0, False);
      Processados.CreateDataSet;


      while Not Encerrar do
      Begin


         Arq_Log := ExtractFileDir(Arq_Log) + '\' + FormatDateTime('yyyy-mm-dd',
            now) + '.log';

         TcpSrvForm.Thgravacao_CalAmp_ultimo := now;

         BuscaArquivo;

         if (Arq_inbox <> '') then
            GravaTracking
         Else
         Begin
            Dormir(50);
         End;

      End;

      Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Gravação CalAmp - Encerrada por Erro: ' + InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;
end;

Procedure gravacao_CalAmp.BuscaArquivo;
Var Arquivos: TSearchRec;
//Var Arq_sql_pendente: String;
//Var Arq_Sql: String;

Begin

   // Checa por arquivo Inbox de posicoes
   Arq_inbox := '';

   if FindFirst(DirInbox + '\*.CAL' + FormatFloat('00', ThreadId), faArchive,
      Arquivos) = 0 then
   begin
      Arq_inbox := DirInbox + '\' + Arquivos.Name;
   End;

   FindClose(Arquivos);

   Sleep(50);

End;

Procedure gravacao_CalAmp.GravaTracking;
Var
   Arq_Proce: String;
   Arq_Err: String;
   Arq_Sql: String;
   SqlExec: String;
   blobF: TBlobField;
   Stream: TMemoryStream;
   Status: SmallInt;
   erro: Boolean;
   StrTmp: String;
   Contador: Word;
   ContErros: Word;

Begin

   ContErros := 0;
   SqlPendente := '';
   Corrigido := 0;

   StrTmp := ExtractFileName(Arq_inbox);

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

   while Not Processar.Eof do
   Begin

//      erro := False;

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


      // Decodifica o Pacote ou o restante dele
      Try
         ZeraRecord;
         Status := Decode(PacketTot);
      Except
         Status := -1;
      End;
      if Status = -1 then
      Begin

//         erro := True;
         Inc(ContErros);
         SqlExec :=
            'insert into CalAmp.recebidos (id, data_rec, tipo, duplicado, ip_origem, pacote) values (';
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

      if Status >= 0 then
      Begin
         Inc(ContErros);
         Processar.Next;
      End
      Else
      Begin
         Processar.Delete;
      End;

   End;


   Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_inbox);
   Arq_Err   := DirErros + '\' + ExtractFileName(Arq_inbox);
   Arq_Sql   := DirSql + '\' + ExtractFileName(Arq_inbox);

   SalvaArquivo(Arq_Sql, SqlPendente);

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

Function gravacao_CalAmp.Decode(pPacket:TByteDynArray): SmallInt;
Var
   StrBits: String;
   Posicao_Decode: Smallint;
//   Status: SmallInt;
Begin

   Try

      Posicao_Decode := 0;

      // Ta Vazio ou menor que 3 bytes ?
      if Length(pPacket) < 3 then
      Begin
         SetLength(pPacket, 0);
         Result := 0;
         Exit;
      End;

      Corrigido := 0;
      PosLimite := 3;
      SetLength(Resposta, 0);

      StrBits := CharToStrBin(pPacket, Posicao_Decode, 1);

      //reseta o inicio !
      Posicao_Decode := 0;

      //Posicao := Decode_Header(pPacket,Posicao,Pack_Header)
      //Se for Pacote de message
      Posicao_Decode := Decode_Options(pPacket,Posicao_Decode,Pack_Options,Arq_Log);
      if Posicao_Decode = -1 then
         SalvaLog(Arq_Log, 'Não decodificou (Decode_Options): ' + PacketStr);

      Posicao_Decode := Decode_Message_Header(pPacket,Posicao_Decode,Pack_Message_Header,Arq_Log);

      if Posicao_Decode = -1 then
         SalvaLog(Arq_Log, 'Não decodificou (Decode_Message_Header): ' + PacketStr)
      //Se for Null Message = Keep Alive
      Else if Pack_Message_Header.Message_Type = 0 then
      Begin
         Result := 0;
         Exit;
      End
      //Event Report
      Else if Pack_Message_Header.Message_Type = 2 then
      Begin
         Posicao_Decode := Decode_Event_Message(pPacket,Posicao_Decode,Pack_Event_Message,Arq_Log);
         if Posicao_Decode = -1 then
            SalvaLog(Arq_Log, 'Não decodificou (Decode_Message_Header): ' + PacketStr);
      End;

      Imprime;

      Result := Posicao_Decode;

   Except

      Begin
         SalvaLog(Arq_Log, 'Não decodificou (2): ' + PacketStr);
         SetLength(pPacket, 0);
         Result := 0;
      End;
   End;

End;


Procedure gravacao_CalAmp.ZeraRecord;
Begin

   // Record Utilizado na Gravacao do Pacote CalAmp Header
   Pack_Header.Version                              := 0;
   Pack_Header.Header_Length                        := 0;
   Pack_Header.Type_Of_Service                      := 0;
   Pack_Header.Total_Lenght                         := 0;
   Pack_Header.Identification                       := 0;
   Pack_Header.Flags                                := 0;
   Pack_Header.TTL                                  := 0;
   Pack_Header.Protocol                             := 0;
   Pack_Header.Header_CheckSum                      := 0;
   Pack_Header.Source_IP                            := '';
   Pack_Header.Destination_IP                       := '';
   Pack_Header.Resposta                             := '';


   // Record Utilizado na Gravacao do Pacote CalAmp Options Header
   Pack_Options.Options_Mobile_id                   := 0;
   Pack_Options.Options_Mobile_Id_Type              := 0;
   Pack_Options.Options_Authentication_Word         := 0;
   Pack_Options.Options_Routing                     := 0;
   Pack_Options.Options_Forwarding                  := 0;
   Pack_Options.Options_Response_Redirection        := 0;
   Pack_Options.Options_NotUsed                     := 0;
   Pack_Options.Options_AlwaysSet                   := 0;
   Pack_Options.Mobile_Id_Length                    := 0;
   Pack_Options.Mobile_Id                           := '';
   Pack_Options.Mobile_Id_Type_Length               := 0;
   Pack_Options.Mobile_Id_Type                      := 0;
   Pack_Options.Authentication_Length               := 0;
   Pack_Options.Authentication                      := '';
   Pack_Options.Routing_length                      := 0;
   Pack_Options.Routing                             := '';
   Pack_Options.Forwarding_Length                   := 0;
   Pack_Options.Forwarding                          := '';
   Pack_Options.Response_Redirection_Length         := 0;
   Pack_Options.Response_Redirection                := '';
   Pack_Options.Options_Extension_Lenght            := 0;
   Pack_Options.Options_Extension                   := '';
   Pack_Options.ESN_Length                          := 0;
   Pack_Options.ESN                                 := '';

   // Record Utilizado na Gravacao do Pacote CalAmp Options Header
   Pack_Message_Header.Service_Type                 := 0;
   Pack_Message_Header.Message_Type                 := 0;
   Pack_Message_Header.Sequence_number              := 0;

   // Record Utilizado na Gravacao do Pacote CalAmp Event Report Message
   Pack_Event_Message.Update_Time                   := 0;
   Pack_Event_Message.Time_Of_Fix                   := 0;
   Pack_Event_Message.Latitude                      := 0;
   Pack_Event_Message.Longitude                     := 0;
   Pack_Event_Message.Altitude                      := 0;
   Pack_Event_Message.Speed                         := 0;
   Pack_Event_Message.Heading                       := 0;
   Pack_Event_Message.Satellites                    := 0;
   Pack_Event_Message.Fix_Status                    := 0;
   Pack_Event_Message.Carrier                       := 0;
   Pack_Event_Message.RSSI                          := 0;
   Pack_Event_Message.Comm_Status                   := 0;
   Pack_Event_Message.HDOP                          := 0;
   Pack_Event_Message.Inputs                        := 0;
   Pack_Event_Message.Unit_Status                   := 0;
   Pack_Event_Message.Event_Index                   := 0;
   Pack_Event_Message.Event_Code                    := 0;
   Pack_Event_Message.Accums                        := 0;
   Pack_Event_Message.Spare                         := 0;
   Pack_Event_Message.AccumList                     := '';

End;

Procedure gravacao_CalAmp.Imprime;
Var Str: String;
Begin

   Str:= '';

   // Record Utilizado na Gravacao do Pacote CalAmp Header
   Str := Str + '   Pack_Header.Version:                       ' + InttoStr(Pack_Header.Version) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Header_Length:                 ' + InttoStr(Pack_Header.Header_Length) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Type_Of_Service:               ' + InttoStr(Pack_Header.Type_Of_Service) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Total_Lenght:                  ' + InttoStr(Pack_Header.Total_Lenght) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Identification:                ' + InttoStr(Pack_Header.Identification) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Flags:                         ' + InttoStr(Pack_Header.Flags) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.TTL:                           ' + InttoStr(Pack_Header.TTL) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Protocol:                      ' + InttoStr(Pack_Header.Protocol) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Header_CheckSum:               ' + InttoStr(Pack_Header.Header_CheckSum) + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Source_IP:                     ' + Pack_Header.Source_IP + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Destination_IP:                ' + Pack_Header.Destination_IP + Char(13) + Char(10);
   Str := Str + '   Pack_Header.Resposta:                      ' + Pack_Header.Resposta + Char(13) + Char(10);
   SalvaLog(Arq_Log, Str);

   Str:= '';
   // Record Utilizado na Gravacao do Pacote CalAmp Options Header
   Str := Str + '   Pack_Options.Options_Mobile_id:            ' + InttoStr(Pack_Options.Options_Mobile_id) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_Mobile_Id_Type:       ' + InttoStr(Pack_Options.Options_Mobile_Id_Type) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_Authentication_Word:  ' + InttoStr(Pack_Options.Options_Authentication_Word) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_Routing:              ' + InttoStr(Pack_Options.Options_Routing) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_Forwarding:           ' + InttoStr(Pack_Options.Options_Forwarding) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_Response_Redirection: ' + InttoStr(Pack_Options.Options_Response_Redirection) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_NotUsed:              ' + InttoStr(Pack_Options.Options_NotUsed) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_AlwaysSet:            ' + InttoStr(Pack_Options.Options_AlwaysSet) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Mobile_Id_Length:             ' + InttoStr(Pack_Options.Mobile_Id_Length) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Mobile_Id:                    ' + Pack_Options.Mobile_Id + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Mobile_Id_Type_Length:        ' + InttoStr(Pack_Options.Mobile_Id_Type_Length) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Mobile_Id_Type:               ' + InttoStr(Pack_Options.Mobile_Id_Type) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Authentication_Length:        ' + InttoStr(Pack_Options.Authentication_Length) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Authentication:               ' + Pack_Options.Authentication + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Routing_length:               ' + InttoStr(Pack_Options.Routing_length) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Routing:                      ' + Pack_Options.Routing + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Forwarding_Length:            ' + InttoStr(Pack_Options.Forwarding_Length) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Forwarding:                   ' + Pack_Options.Forwarding + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Response_Redirection_Length:  ' + InttoStr(Pack_Options.Response_Redirection_Length) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Response_Redirection:         ' + Pack_Options.Response_Redirection + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_Extension_Lenght:     ' + InttoStr(Pack_Options.Options_Extension_Lenght) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.Options_Extension:            ' + Pack_Options.Options_Extension + Char(13) + Char(10);
   Str := Str + '   Pack_Options.ESN_Length:                   ' + InttoStr(Pack_Options.ESN_Length) + Char(13) + Char(10);
   Str := Str + '   Pack_Options.ESN:                          ' + Pack_Options.ESN + Char(13) + Char(10);
   SalvaLog(Arq_Log, Str);

   Str:= '';
   // Record Utilizado na Gravacao do Pacote CalAmp Options Header
   Str := Str + '   Pack_Message_Header.Service_Type           ' + InttoStr(Pack_Message_Header.Service_Type) + Char(13) + Char(10);
   Str := Str + '   Pack_Message_Header.Message_Type           ' + InttoStr(Pack_Message_Header.Message_Type) + Char(13) + Char(10);
   Str := Str + '   Pack_Message_Header.Sequence_number        ' + InttoStr(Pack_Message_Header.Sequence_number) + Char(13) + Char(10);
   SalvaLog(Arq_Log, Str);

   Str:= '';
   // Record Utilizado na Gravacao do Pacote CalAmp Event Report Message
   Str := Str + '   Pack_Event_Message.Update_Time             ' + FormatDateTime('yyyy-mm-dd hh:nn:ss',Pack_Event_Message.Update_Time) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Time_Of_Fix             ' + FormatDateTime('yyyy-mm-dd hh:nn:ss',Pack_Event_Message.Time_Of_Fix) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Latitude                ' + FormatFloat('#.000000',Pack_Event_Message.Latitude) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Longitude               ' + FormatFloat('#.000000',Pack_Event_Message.Longitude) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Altitude                ' + inttoStr(Pack_Event_Message.Altitude) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Speed                   ' + inttoStr(Pack_Event_Message.Speed) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Heading                 ' + inttoStr(Pack_Event_Message.Heading) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Satellites              ' + inttoStr(Pack_Event_Message.Satellites) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Fix_Status              ' + inttoStr(Pack_Event_Message.Fix_Status) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Carrier                 ' + inttoStr(Pack_Event_Message.Carrier) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.RSSI                    ' + inttoStr(Pack_Event_Message.RSSI) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Comm_Status             ' + inttoStr(Pack_Event_Message.Comm_Status) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.HDOP                    ' + inttoStr(Pack_Event_Message.HDOP) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Inputs                  ' + inttoStr(Pack_Event_Message.Inputs) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Unit_Status             ' + inttoStr(Pack_Event_Message.Unit_Status) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Event_Index             ' + inttoStr(Pack_Event_Message.Event_Index) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Event_Code              ' + inttoStr(Pack_Event_Message.Event_Code) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Accums                  ' + inttoStr(Pack_Event_Message.Accums) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.Spare                   ' + inttoStr(Pack_Event_Message.Spare) + Char(13) + Char(10);
   Str := Str + '   Pack_Event_Message.AccumList               ' + Pack_Event_Message.AccumList + Char(13) + Char(10);
   SalvaLog(Arq_Log, Str);

End;

{ A função dormir deve ser repetida em cada thread, prar evitar sincronismo}
Procedure gravacao_CalAmp.Dormir(pTempo: Word);
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


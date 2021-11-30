unit thread_gravacao_satlight;

interface

uses
   Windows, SysUtils, Classes, Math, DB, DBClient, Types,
   ZConnection, ZDataset, ZAbstractRODataset, ZSqlProcessor,
   OverbyteIcsWSocket, OverbyteIcsWSocketS, OverbyteIcsWndControl,
   DateUtils, FuncColetor, FunAcp;

type
   gravacao_satlight = class(TThread)

   public

      // Parametros recebidos
      db_inserts: Integer; // Insert Simultaneo
      db_hostname: String; // Nome do Host
      db_username: String; // Usuario
      db_database: String; // Database
      db_password: String; // Password
      Arq_Log: String;
      DirInbox: String;
      DirProcess: String;
      DirErros: String;
      DirSql: String;
      ThreadId: Word;
      Encerrar: Boolean;
      Debug: Integer;
      PortaLocal: Integer;
      ServerStartUp: tDateTime;
      srv_proto: String;
      srv_addr: String;

      // Objetos
      QryBatch: TZSqlProcessor; // Um objeto query local
      QryStatus: TZReadOnlyQuery; // Um objeto query local
      conn: TZConnection; // Uma tconnection local
      Arq_inbox: String;

   private
      { Private declarations }
      SqlTracking: String;
      SqlPendente: String;
      PacketStr: String;
      PacketTot: TByteDynArray;
//      PacketRec: TByteDynArray;
      Tracking: Array Of tsatpack;
      Mensagens: Array Of tsatmens;
      Erro: Boolean;
      Tipo_Track: Word;
      Tipo_Equip: Word;
      Serial: String;
      Resposta: Byte;
      Valido: Boolean;

   protected

      Processar: tClientDataSet;
      Processado: tClientDataSet;
      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaDatabase;
      Procedure ZeraRecord;
      Procedure Decode;
      Procedure Dormir(pTempo: Word);

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure gravacao_satlight.Execute;
begin
   Try
      // CarregaValores;
      conn := TZConnection.Create(nil);
      QryBatch := TZSqlProcessor.Create(Nil);
      QryStatus := TZReadOnlyQuery.Create(Nil);
      conn.HostName := db_hostname;
      conn.User := db_username;
      conn.Password := db_password;
      conn.Database := db_database;
      conn.Protocol := 'mysql';
      conn.Port := 3306;
      QryBatch.Connection := conn;
      QryStatus.Connection := conn;

      conn.Properties.Add('sort_buffer_size=4096');
      conn.Properties.Add('join_buffer_size=64536');


      SqlTracking :=
         'insert into nexsat.posicoes_carga (id, dh_gps, codigo, latitude, longitude, porta, ip_remoto, porta_remoto, velocidade, angulo, tensao, qtdade_satelite, breakdown1, breakdown2, breakdown3, atualizado, chave, panico1, bateria, marc_codigo ) ';
      Processar := tClientDataSet.Create(nil);
      Processar.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processar.FieldDefs.Add('IP', ftString, 15, False);
      Processar.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processar.FieldDefs.Add('ID', ftString, 20, False);
      Processar.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Processar.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Processar.FieldDefs.Add('Processado', ftBoolean, 0, False);
      Processar.CreateDataSet;

      Processado := tClientDataSet.Create(nil);
      Processado.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
      Processado.FieldDefs.Add('IP', ftString, 15, False);
      Processado.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processado.FieldDefs.Add('ID', ftString, 20, False);
      Processado.FieldDefs.Add('Resposta', ftBlob, 0, False);
      Processado.CreateDataSet;

      Try
         conn.Connect;
      Except
         SalvaLog(Arq_Log, 'Erro ao conectar com o MySql: ');
      End;

      while Not Encerrar do
      Begin

         Arq_Log := ExtractFileDir(Arq_Log) + '\' + FormatDateTime('yyyy-mm-dd',
            now) + '.log';

         TcpSrvForm.Thgravacao_satlight_ultimo := now;

         Try
            if (Not conn.PingServer) then
            Begin
               conn.Disconnect;
               conn.Connect;
            End;
         Except
            SalvaLog(Arq_Log, 'Erro ao "pingar" o MySql: ');
            Dormir(30000);
            Continue;
         End;

         if (Not conn.Connected) then
            Try
               conn.Disconnect;
               conn.Connect;
            Except
               SalvaLog(Arq_Log, 'Erro ao conectar com o MySql: ');
               Dormir(30000);
               Continue;
            End;

         BuscaArquivo;

         if (Arq_inbox <> '') then
            GravaDatabase
         Else
         Begin
            Sleep(500);
         End;

      End;

      Sleep(100);

      QryStatus.Close;
      conn.Disconnect;
      QryBatch.Free;
      QryStatus.Free;
      Processar.Free;
      Processado.Free;
      conn.Free;
      Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Gravação SatLight - Encerrada por Erro: '
         + InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;
end;

Procedure gravacao_satlight.BuscaArquivo;
Var
   Arquivos: TSearchRec;

Begin

   Arq_inbox := '';

   if FindFirst(DirInbox + '\*.SAT' + FormatFloat('00', ThreadId), faArchive,
      Arquivos) = 0 then
   begin
      Arq_inbox := DirInbox + '\' + Arquivos.Name;
   End;

   FindClose(Arquivos);
   Sleep(50);

End;

Procedure gravacao_satlight.GravaDatabase;
Var
   Arq_Proce: String;
   Arq_Err: String;
   Arq_Sql: String;
   SqlExec: String;
   blobF: TBlobField;
   Stream: TMemoryStream;
   blobR: TBlobField;
   StreamRes: TMemoryStream;
//   TipoPacket: SmallInt;
//   FileDate: tDateTime;
   StrTmp: String;
   tInicio: tDateTime;
   tFinal: tDateTime;
   Contador: Word;
   ContTrack: Word;
   ContErros: Word;

Begin

   ContErros := 0;
   ContTrack := 0;
   SqlPendente := '';

   StrTmp := ExtractFileName(Arq_inbox);

{   Try
      FileDate := EncodeDateTime(StrtoInt(Copy(StrTmp, 1, 4)),
         StrtoInt(Copy(StrTmp, 6, 2)), StrtoInt(Copy(StrTmp, 9, 2)),
         StrtoInt(Copy(StrTmp, 12, 2)), StrtoInt(Copy(StrTmp, 15, 2)),
         StrtoInt(Copy(StrTmp, 18, 2)), 0);
   Except
      FileDate := now;
   End;
}
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

      Erro := False;

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
         Inc(ContErros);
         Processar.Next;
         Continue;
      End;

      // Inicializa o Vetor de Mensagens
      SetLength(Mensagens, 0);
      // Inicializa o Vetor de Tracking
      SetLength(Tracking, 0);

      try
         Decode;
      Except
         SalvaLog(Arq_Log, 'Erro no Decode do Pacote');
         Processar.Next;
         Inc(ContErros);
         Continue;
      end;

      Try

         SqlExec :=
            'Insert into  satlight.satlight_recebido (carg_id, carg_sequencia, carg_ip, carg_porta, carg_dados) ';
         SqlExec := SqlExec + 'Values(';
         SqlExec := SqlExec + QuotedStr(Serial) + ',';
         SqlExec := SqlExec + InttoStr(Processar.FieldByName('MsgSequencia')
            .AsInteger) + ', ';
         SqlExec := SqlExec + 'INET_ATON(' +
            QuotedStr(Processar.FieldByName('IP').AsString) + '), ';
         SqlExec := SqlExec + Processar.FieldByName('Porta').AsString + ', ';
         SqlExec := SqlExec + QuotedStr(PacketStr) + '); ';

         SqlPendente := SqlExec;

      Except

         SalvaLog(Arq_Log, 'Erro no Comando insert - Satlight Recebidos: '
            + SqlExec);

      End;

      if (Length(Tracking) = 0) and (Length(Mensagens) = 0) then
      Begin
         SalvaLog(Arq_Log, 'Pacote Inválido: ' + PacketStr);
         Processar.Next;
         Inc(ContErros);
         Continue;
      End;

      // Salva os dados de tracking
      if (Length(Tracking) > 0) then
         for Contador := 0 to Length(Tracking) - 1 do
         Begin
            Try
               SqlExec := SqlTracking;
               SqlExec := SqlExec + 'Select ';
               SqlExec := SqlExec + QuotedStr(Serial) + ', ';
               SqlExec := SqlExec + 'DATE_SUB( ' +
                  QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',
                  Tracking[Contador].Timestamp)) +
                  ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Codigo) + ', ';
               SqlExec := SqlExec +
                  Troca(FormatFloat('###0.######',
                  Tracking[Contador].Latitude)) + ', ';
               SqlExec := SqlExec +
                  Troca(FormatFloat('###0.######',
                  Tracking[Contador].Longitude)) + ', ';
               SqlExec := SqlExec + InttoStr(PortaLocal) + ', ';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('IP')
                  .AsString) + ', ';
               SqlExec := SqlExec + QuotedStr(Processar.FieldByName('Porta')
                  .AsString) + ', ';
               SqlExec := SqlExec +
                  InttoStr(Tracking[Contador].Velocidade) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Angulo) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Tensao) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Qt_sat) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Evento) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Flag1) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Flag2) + ', ';
               SqlExec := SqlExec +
                  InttoStr(Tracking[Contador].Atualizado) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Chave) + ', ';
               SqlExec := SqlExec + InttoStr(Tracking[Contador].Panico) + ', ';
               if Tracking[Contador].BatPrincipal = 0 then
                  SqlExec := SqlExec + '1, '
               Else
                  SqlExec := SqlExec + '0, ';

               SqlExec := SqlExec + '88';
               SqlExec := SqlExec +
                  ' from dual where not exists (select 1 from posicoes where id = '
                  + QuotedStr(Serial) + ' and codigo = ' +
                  InttoStr(Tracking[Contador].Codigo) + ');';

               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

            Except
               Erro := True;
               SalvaLog(Arq_Log, 'Erro ao Gerar o Sql - Tracking: ');
            End;
         End;

      // Salva os dados de mensagens / Comandos recebidos
      if (Length(Mensagens) > 0) then
         for Contador := 0 to Length(Mensagens) - 1 do
         Begin
            Try
               SqlExec :=
                  'Insert into comandos_retorno(id,sequencia,comando,dt_retorno) ';
               SqlExec := SqlExec + ' Values (';
               SqlExec := SqlExec + QuotedStr(Mensagens[Contador].Serial) + ',';
               SqlExec := SqlExec +
                  InttoStr(Mensagens[Contador].Sequencia) + ',';
               SqlExec := SqlExec +
                  QuotedStr(Mensagens[Contador].Comando) + ',';
               SqlExec := SqlExec + 'Now()) ';
               SqlExec := SqlExec +
                  'ON DUPLICATE KEY UPDATE dt_retorno = now();';
               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

               SqlExec := 'Update Nexsat.comandos_envio Set Status = 99' +
                  ' Where id = ' + QuotedStr(Mensagens[Contador].Serial) +
                  ' and Sequencia = ' + InttoStr(Mensagens[Contador].Sequencia)
                  + ' and Status in (1,3); ' + Char(13) + Char(10);
               SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

            Except
               Erro := True;
               SalvaLog(Arq_Log, 'Erro ao Gerar o Sql - Mensagens: ');
            End;
         End;

      // --Insert into comandos_retorno(id,sequencia,comando,dt_retorno)

      // Salva o Id Decodificado
      if (Length(Tracking) > 0) Then
         Try
            Processado.Insert;
            Processado.FieldByName('ID').AsString := Serial;
            Processado.FieldByName('IP').AsString :=
               Processar.FieldByName('IP').AsString;
            Processado.FieldByName('Porta').AsString :=
               Processar.FieldByName('Porta').AsString;
            Processado.FieldByName('Tcp_Client').AsString :=
               Processar.FieldByName('Tcp_Client').AsString;
            if Resposta > 0 then
            Begin
               StreamRes := TMemoryStream.Create;
               blobR := Processado.FieldByName('Resposta') as TBlobField;
               Try
                  try
                     blobR.LoadFromStream(StreamRes);
                  finally
                     StreamRes.Free;
                  end;
               Except
                  Erro := True;
                  SalvaLog(Arq_Log, 'Erro ao Salvar o TBlobField-Resposta: ');
               End;
            End;

            Processado.Post;
            Erro := False;

         Except

            SalvaLog(Arq_Log, 'Erro ao Inserir Resposta: ');
            Erro := True;

         End;

      if Erro then
      Begin
         Inc(ContErros);
         Processar.Next;
      End
      Else
      Begin
         Inc(ContTrack);
         Processar.Delete;
      End;

   End;

   tFinal := now;

   if Debug In [5, 9] then
      SalvaLog(Arq_Log, 'Tempo execução Decode: ' + FormatDateTime('ss:zzz',
         tFinal - tInicio) + ' Segundos');

   Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_inbox);
   Arq_Err := DirErros + '\' + ExtractFileName(Arq_inbox);
   Arq_Sql := DirSql + '\' + ExtractFileName(Arq_inbox);

   tInicio := now;

   If not ExecutarBatch(SqlPendente, Arq_Log, QryBatch) Then
   Begin
      SalvaLog(Arq_Log, 'Erro ao executar sql batch: ' + Arq_Sql);
      SalvaArquivo(Arq_Sql, SqlPendente);
   End;

   tFinal := now;

   if Debug In [2, 5, 9] then
      SalvaLog(Arq_Log, 'Tempo execução Sql batch: ' + Arq_inbox + ' - ' +
         FormatDateTime('ss:zzz', tFinal - tInicio) + ' Segundos');

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

   AtualizaStatus(PortaLocal, ContTrack, ContTrack, 0, -1, Arq_Log, QryStatus);

   Sleep(10);

End;

Procedure gravacao_satlight.Decode;
Var
   Contador: SmallInt;
   Tamanho: Integer;
   Posicao: SmallInt;
   Sequencia: Integer;
   Qtd_Track: Byte;
   StrBits: String;
   CRC: Integer;
   StrMens: String;

Begin

   Resposta := 0;
   Posicao := 0;
   Tamanho := Length(PacketTot);

   Try

      if Tamanho < 18 then
      Begin
         SetLength(PacketTot, 0);
         SetLength(Mensagens, 0);
         Exit;
      End;

      // 1. Byte - Tipo de pacote
      StrBits := CharToStrBin(PacketTot, Posicao, 1);
      Tipo_Track := BintoInt(StrBits);

      // Resposta de Comando Enviado
      if Tipo_Track = $30 then
      Begin

         Erro := False;

         Contador := 0;
         SetLength(Mensagens, 0);

         Try
            Begin

               Serial := Chr(PacketTot[4]) + Chr(PacketTot[5]) +
                  Chr(PacketTot[6]) + Chr(PacketTot[7]) + Chr(PacketTot[8]) +
                  Chr(PacketTot[9]) + Chr(PacketTot[10]) + Chr(PacketTot[11]);
               Sequencia := StrtoInt(Chr(PacketTot[12]) + Chr(PacketTot[13]) +
                  Chr(PacketTot[14]) + Chr(PacketTot[15]) + Chr(PacketTot[16]) +
                  Chr(PacketTot[17]));

               Tamanho := 18;

               while Tamanho < Length(PacketTot) - 1 do
               Begin

                  if (PacketTot[Tamanho] = 59) then
                  Begin
                     SalvaLog(Arq_Log, 'Erro no Decode - Tamanho = 59 : ');
                     Break
                  End
                  Else if (PacketTot[Tamanho] = 00) then
                  Begin
                     SalvaLog(Arq_Log, 'Erro no Decode - Tamanho = 0: ');
                     Break;
                  End;

                  SetLength(Mensagens, Contador + 1);
                  Mensagens[Contador].Serial := Serial;
                  Mensagens[Contador].Sequencia := Sequencia;
                  Mensagens[Contador].Comando := '';
                  StrMens := '';

                  while Tamanho < Length(PacketTot) - 1 do
                  Begin
                     if (PacketTot[Tamanho] = 59) then
                        Break;

                     StrMens := StrMens + Chr(PacketTot[Tamanho]);
                     Inc(Tamanho);

                  End;

                  Mensagens[Contador].Comando := StrMens;

                  if Debug In [5, 9] then
                     SalvaLog(Arq_Log, 'Mensagem recebida: ' +
                        Mensagens[Contador].Comando);

                  Inc(Contador);

               End;

            End;
         except
            SalvaLog(Arq_Log, 'Erro ao decodificar a mensagem recebida: ' +
               Serial + '/' + InttoStr(Sequencia) + '/' + StrMens);
         End;

      End
      Else
      Begin

         // 1. Byte - Tipo Equipamento
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         Tipo_Equip := BintoInt(StrBits);

         // 4. Bytes - Serial
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         Serial  := inttohex(BintoInt(StrBits),2);
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         Serial  := Serial + inttohex(BintoInt(StrBits),2);
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         Serial  := Serial + inttohex(BintoInt(StrBits),2);
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         Serial  := Serial + inttohex(BintoInt(StrBits),2);



         // 1. Bytes - Sequencia de transmissao
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         Sequencia := BintoInt(StrBits);

         // 1. Bytes - Qtd Tracking
         StrBits := CharToStrBin(PacketTot, Posicao, 1);
         Qtd_Track := BintoInt(StrBits);

         // 2Ultimos Bytes - CRC
         Posicao := Tamanho - 1;
         StrBits := CharToStrBin(PacketTot, Posicao, 2);
         CRC := BintoInt(StrBits);

         // Reseta a Posicao de Leitura Foi alterada para leitura do CRC
         Posicao := 8;

         // Critica de tamanho
         // Pacote de 21 Bytes
         if Tipo_Track = $FF then
         Begin
            // Se o número de trackings* Tamanho + Header + Crc = Tamanho, Está OK
            if (((Qtd_Track * 21) + 8 + 2) = Tamanho) then
               Valido := True
            Else
               Valido := False;
         End
         // Pacote de 31 Bytes
         Else if Tipo_Track = $FE then
         Begin
            // Se o número de trackings* Tamanho + Header + Crc = Tamanho, Está OK
            if ((Qtd_Track * 31) + 8 + 2) = Tamanho then
               Valido := True
            Else
               Valido := False;
         End;

         if Valido then
         Begin

            Erro := False;

            for Contador := 1 to Qtd_Track do
            Begin

               SetLength(Tracking, Contador);

               // 4 bytes - Codigo Sequencial
               StrBits := CharToStrBin(PacketTot, Posicao, 4);
               Tracking[Contador - 1].Codigo := BintoInt(StrBits);

               // 1 Bytes - Evento Gerador
               StrBits := CharToStrBin(PacketTot, Posicao, 1);
               Tracking[Contador - 1].Evento := BintoInt(StrBits);

               // 4 Bytes - TimeStamp
               StrBits := CharToStrBin(PacketTot, Posicao, 4);
               Tracking[Contador - 1].Timestamp :=
                  TimeStamptoDateTime(BintoInt(StrBits));

               // 4 Bytes - Latitude
               StrBits := CharToStrBin(PacketTot, Posicao, 4);
               Tracking[Contador - 1].Latitude := CompTwoToDouble(StrBits);

               // 4 Bytes - Longitude
               StrBits := CharToStrBin(PacketTot, Posicao, 4);
               Tracking[Contador - 1].Longitude    := CompTwoToDouble(StrBits);

               // 1 Byte - Velocidade
               StrBits := CharToStrBin(PacketTot, Posicao, 1);
               Tracking[Contador - 1].Velocidade   := BintoInt(StrBits);

               // 1 Byte - Bateria
               StrBits := CharToStrBin(PacketTot, Posicao, 1);
               Tracking[Contador - 1].Tensao := Trunc(BintoInt(StrBits) * 0.2);

               // 1 Byte - Flag1
               StrBits := CharToStrBin(PacketTot, Posicao, 1);
               Tracking[Contador - 1].Flag1        := BintoInt(StrBits);
               //Presença de Bateria Backup
               Tracking[Contador - 1].BatBackup    := BintoInt(StrBits[1]);
               //Presença de Bateria Principal
               Tracking[Contador - 1].BatPrincipal := BintoInt(StrBits[2]);

               Tracking[Contador - 1].Atualizado   := BintoInt(StrBits[5]);

               Tracking[Contador - 1].Qt_sat       := BintoInt(Copy(StrBits, 1, 4));

               // 1 Byte - Flag2
               StrBits := CharToStrBin(PacketTot, Posicao, 1);
               Tracking[Contador - 1].Flag2        := BintoInt(StrBits);
               Tracking[Contador - 1].RSSI         := BintoInt(Copy(StrBits, 1, 3));
               Tracking[Contador - 1].PPC          := BintoInt(StrBits[4]);
               Tracking[Contador - 1].Panico       := BintoInt(StrBits[5]);
               Tracking[Contador - 1].EDN          := BintoInt(StrBits[6]);
               Tracking[Contador - 1].Chave        := BintoInt(StrBits[7]);
               Tracking[Contador - 1].Bloqueio     := BintoInt(StrBits[8]);

               // Se for do Tipo Tracking completo, Pular + 14 Bytes;
               If Tipo_Track = $FE Then
                  CharToStrBin(PacketTot, Posicao, 10);

            End;

            Resposta := Qtd_Track;
            // TcpSrvForm.AckNackSatlight(Processar.FieldByName('IP').AsString,Processar.FieldByName('Porta').AsString,Qtd_Track);

         End; // If Valido

      End;

   Except

      SalvaLog(Arq_Log, 'Erro no Decode - SatLight: ');
      Erro := True;

   End;

End;

Procedure gravacao_satlight.ZeraRecord;
Begin

   SetLength(Tracking, 0);

End;

Procedure gravacao_satlight.Dormir(pTempo: Word);
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


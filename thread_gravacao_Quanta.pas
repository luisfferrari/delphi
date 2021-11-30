
unit thread_gravacao_Quanta;

interface

uses
   Windows, SysUtils, Classes, Math, DB, DBClient, Types,
   DateUtils, FuncColetor, FunAcp, FunQuanta;

type
   gravacao_quanta = class(TThread)

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
      ThreadId: SmallInt;
      Encerrar: Boolean;
      Debug: Integer;
      Debug_ID: String;
      PortaLocal: Integer;
      ServerStartUp: tDateTime;
      Arq_inbox: String;
      // Objetos

   private
      { Private declarations }
      QuantaTracking : Array Of tquanta_Tracking;
      QuantaEventos:   Array [0..16] Of tquanta_Eventos;
      SqlTracking:     String;
      SqlPendente:     String;
      PacketTot:       TByteDynArray;
      Corrigido:       SmallInt;
      QuantaProduto:   SmallInt;
      QuantaVersao:    SmallInt;
      QuantaTipo:      SmallInt;
      ErroDecode:      SmallInt;

   protected

      Processar: tClientDataSet;
      procedure Execute; override;
      Procedure BuscaArquivo;
      Procedure GravaTracking;
      Procedure Dormir(pTempo: SmallInt);
      Function DecodeQuanta(pProduto,pTipo: Byte):Boolean;
      Function Decode_31_4C(var pInicio: SmallInt): SmallInt;
      Function Decode_99_0D(var pInicio: SmallInt): SmallInt;
      Function Decode_99_12(var pInicio: SmallInt): SmallInt;
      Function Decode_50_12(var pInicio: SmallInt): SmallInt;
      Function Busca_evento(pProduto,pevento: SmallInt): SmallInt;
   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure gravacao_quanta.Execute;
begin
   Try
      //Inicializa Vetor de Conversao Eventos
      QuantaEventos[0].Produto        := $31;
      QuantaEventos[0].Evento         := $0001; //Ignição (PPC) violado
      QuantaEventos[0].Evento_interno := 0;
      QuantaEventos[1].Produto        := $31;
      QuantaEventos[1].Evento         := $0011; //Entrada de bateria violada
      QuantaEventos[1].Evento_interno := 1;
      QuantaEventos[2].Produto        := $31;
      QuantaEventos[2].Evento         := $0040; //Wake Up, quando o RADAR DUO estiver em Sleep
      QuantaEventos[2].Evento_interno := 2;
      QuantaEventos[3].Produto        := $31;
      QuantaEventos[3].Evento         := $0051; // Ignição (PPC) desviolado
      QuantaEventos[3].Evento_interno := 3;
      QuantaEventos[4].Produto        := $31;
      QuantaEventos[4].Evento         := $0061; // Entrada de bateria desviolada
      QuantaEventos[4].Evento_interno := 4;
      QuantaEventos[5].Produto        := $31;
      QuantaEventos[5].Evento         := $1050; // Envento gerador de TE de Jammer
      QuantaEventos[5].Evento_interno := 5;
      QuantaEventos[6].Produto        := $31;
      QuantaEventos[6].Evento         := $4000; // RADAR DUO entrou em sleep Mode
      QuantaEventos[6].Evento_interno := 6;
      QuantaEventos[7].Produto        := $31;
      QuantaEventos[7].Evento         := $0000; //Outros Eventos
      QuantaEventos[7].Evento_interno := 9;
      QuantaEventos[8].Produto        := $31;
      QuantaEventos[8].Evento         := $8000; //Entrada de bateria violada
      QuantaEventos[8].Evento_interno := 1;

      QuantaEventos[9].Produto        := $99;
      QuantaEventos[9].Evento         := $0001; // Ignição (PPC) violado
      QuantaEventos[9].Evento_interno := 0;
      QuantaEventos[10].Produto       := $99;
      QuantaEventos[10].Evento        := $0011; // Entrada de bateria violada
      QuantaEventos[10].Evento_interno:= 1;
      QuantaEventos[11].Produto       := $99;
      QuantaEventos[11].Evento        := $0040; // Wake Up, quando o TETROS estiver em Sleep
      QuantaEventos[11].Evento_interno:= 2;
      QuantaEventos[12].Produto       := $99;
      QuantaEventos[12].Evento        := $0051; // Ignição (PPC) desviolado
      QuantaEventos[12].Evento_interno:= 3;
      QuantaEventos[13].Produto       := $99;
      QuantaEventos[13].Evento        := $0061; // Entrada de bateria desviolada
      QuantaEventos[13].Evento_interno:= 4;
      QuantaEventos[14].Produto       := $99;
      QuantaEventos[14].Evento        := $4000; // TETROS entrou em sleep Mode
      QuantaEventos[14].Evento_interno:= 6;
      QuantaEventos[15].Produto       := $99;
      QuantaEventos[15].Evento        := $8000; // Bateria do Veículo violada
      QuantaEventos[15].Evento_interno:= 1;
      QuantaEventos[16].Produto       := $99;
      QuantaEventos[16].Evento        := $1000; // Tracking
      QuantaEventos[16].Evento_interno:= 9;


      // CarregaValores;
      SqlTracking := 'insert into nexsat.' + db_tablecarga + ' ';
      SqlTracking := SqlTracking + '(id, dh_gps, latitude, longitude, porta, ip_remoto, porta_remoto, velocidade, angulo, qtdade_satelite, tensao, odometro, temp, atualizado, chave, sinal, bateria, bateria_violada, bateria_religada, marc_codigo, produto, versao, dt_jammer) ';

      Processar := tClientDataSet.Create(nil);
      Processar.FieldDefs.Add('IP', ftString, 15, False);
      Processar.FieldDefs.Add('Porta', ftInteger, 0, False);
      Processar.FieldDefs.Add('ID', ftString, 20, False);
      Processar.FieldDefs.Add('MsgSequencia', ftInteger, 0, False);
      Processar.FieldDefs.Add('Datagrama', ftBlob, 0, False);
      Processar.FieldDefs.Add('Produto', ftInteger, 0, False);
      Processar.FieldDefs.Add('Tipo', ftInteger, 0, False);
      Processar.FieldDefs.Add('Versao', ftInteger, 0, False);
      Processar.FieldDefs.Add('Duplicado', ftInteger, 0, False);
      Processar.FieldDefs.Add('Coderro', ftInteger, 0, False);

      Processar.CreateDataSet;

      while Not Encerrar do
      Begin

         Arq_Log := ExtractFileDir(Arq_Log) + '\' + FormatDateTime('yyyy-mm-dd',
            now) + '.log';

         TcpSrvForm.Thgravacao_quanta_ultimo[ThreadId] := now;

         BuscaArquivo;

         if (Arq_inbox <> '') then
            GravaTracking
         Else
         Begin
            Dormir(100);
         End;

      End;

      SalvaLog(Arq_Log, 'Pedido de encerramento da Thread Gravação & Decoder Quanta: ' + InttoStr(ThreadId));
      Free;

   Except

      SalvaLog(Arq_Log, 'ERRO - Thread Gravação & Decoder Quanta - Encerrada por Erro: ' + InttoStr(ThreadId));

      Encerrar := True;
      Self.Free;

   End;
end;

Procedure gravacao_quanta.BuscaArquivo;
Var
   Arquivos: TSearchRec;
//   Arq_sql_pendente: String;
//   Arq_Sql: String;

Begin

   // Checa por arquivo Inbox de posicoes
   Arq_inbox := '';

   if FindFirst(DirInbox + '\*.QUA' + FormatFloat('00', ThreadId), faArchive, Arquivos) = 0 then
   begin
      Arq_inbox := DirInbox + '\' + Arquivos.Name;
   End;

   FindClose(Arquivos);

   Sleep(100);

End;

Procedure gravacao_quanta.GravaTracking;
Var
   Arq_Proce: String;
   Arq_Err: String;
   Arq_Sql: String;
   SqlExec: String;
   blobF: TBlobField;
   Stream: TMemoryStream;
   blobR: TBlobField;
   StreamRes: TMemoryStream;

   StrTmp: String;
   Contador: SmallInt;
   ContErros: SmallInt;
   PacketStr: string;

Begin

try

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

   Try
      Processar.First;

//      tInicio := now();

      while Not Processar.Eof do
      Begin

         QuantaProduto := Processar.FieldByName('Produto').AsInteger;
         QuantaTipo    := Processar.FieldByName('Tipo').AsInteger;
         QuantaVersao  := Processar.FieldByName('Versao').AsInteger;

         // Leitura do arquivo de recebidos
         Try

            Stream     := TMemoryStream.Create;
            blobF      := Processar.FieldByName('DataGrama') as TBlobField;

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

         //Se veio com erro, seta o erro para gravar
         if (Processar.FieldByName('Coderro').AsInteger > 0 ) then
         Begin
            ErroDecode := 1;
            Setlength(QuantaTracking,0)
         End
         Else
         Begin
            Try
               //decodifica o pacote fisicamente
               ErroDecode := 0;
               DecodeQuanta(QuantaProduto,QuantaTipo);
            Except
               Inc(ContErros);
               SalvaLog(Arq_Log, 'Erro No DecodeQuanta: ');
            End;
         End;

         if (length(QuantaTracking) > 0) then
         Begin
            for Contador := 0  to length(QuantaTracking)-1 do
            Begin
               Try

                  If (QuantaProduto = $31) and (QuantaTracking[Contador].EventoQuanta <> 28672) Then
                     Begin
                        SqlExec   := 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) ';
                        SqlExec   := SqlExec +  ' Values(';
                        SqlExec   := SqlExec +   QuotedStr(Processar.FieldByName('ID').AsString ) + ',';//ID
                        SqlExec   := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',
                                                            QuantaTracking[Contador].dh_violacao)) +
                                                        ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec   := SqlExec + QuotedStr('QUANTA_' + InttoStr(QuantaProduto)) + ',';
                        SqlExec   := SqlExec + InttoStr(QuantaTracking[Contador].EventoQuanta) + ');';  //Codigo Alerta
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                        SqlExec := '';
                     End
                  Else If (QuantaProduto <> $31) and (QuantaTracking[Contador].EventoQuanta <> 4096) Then
                     Begin
                        SqlExec   := 'Insert ignore into nexsat.eventos (ID, DH_GPS, TIPO, CODIGO) ';
                        SqlExec   := SqlExec +  ' Values(';
                        SqlExec   := SqlExec +   QuotedStr(Processar.FieldByName('ID').AsString ) + ',';//ID
                        SqlExec   := SqlExec + 'DATE_SUB( ' + QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',
                                                            QuantaTracking[Contador].dh_violacao)) +
                                                        ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                        SqlExec   := SqlExec + QuotedStr('QUANTA_' + InttoStr(QuantaProduto)) + ',';
                        SqlExec   := SqlExec + InttoStr(QuantaTracking[Contador].EventoQuanta) + ');';  //Codigo Alerta
                        SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                        SqlExec := '';
                     End;

               Except
                  SalvaLog(Arq_Log, 'Erro ao Gerar Sql-Eventos Tread Id: ' + InttoStr(ThreadId) + ' : ' + SqlExec);
               End;

               Try
                  SqlExec := SqlTracking;
                  SqlExec := SqlExec + 'Values(';
                  SqlExec := SqlExec + QuotedStr(Processar.FieldByName('ID').AsString ) + ', ';
                  SqlExec := SqlExec + 'DATE_SUB( ' +
                     QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',
                     QuantaTracking[Contador].dh_violacao)) +
                     ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour), ';
                  SqlExec := SqlExec +
                     Troca(FormatFloat('###0.######',
                     QuantaTracking[Contador].Latitude)) + ', ';
                  SqlExec := SqlExec +
                     Troca(FormatFloat('###0.######',
                     QuantaTracking[Contador].Longitude)) + ', ';
                  SqlExec := SqlExec + InttoStr(PortaLocal) + ', ';
                  SqlExec := SqlExec + QuotedStr(Processar.FieldByName('IP')
                     .AsString) + ', ';
                  SqlExec := SqlExec + QuotedStr(Processar.FieldByName('Porta')
                     .AsString) + ', ';
                  SqlExec := SqlExec +
                     InttoStr(QuantaTracking[Contador].Velocidade) + ', ';
                  SqlExec := SqlExec +
                     InttoStr(QuantaTracking[Contador].Angulo) + ', ';
                  SqlExec := SqlExec + InttoStr(QuantaTracking[Contador].Num_Satelites) + ', ';
                  SqlExec := SqlExec + InttoStr(QuantaTracking[Contador].Tensao) + ', ';
                  SqlExec := SqlExec + InttoStr(QuantaTracking[Contador].Odometro) + ', ';
                  SqlExec := SqlExec + InttoStr(QuantaTracking[Contador].Temperatura) + ', ';
                  SqlExec := SqlExec + InttoStr(QuantaTracking[Contador].Posicao_valida) + ', ';
                  if QuantaTracking[Contador].Ignicao then
                     SqlExec := SqlExec +  '1, '
                  Else
                     SqlExec := SqlExec +  '0, ';

                  SqlExec := SqlExec + InttoStr(QuantaTracking[Contador].RSSI) + ', ';

                  //Flag de Bateria
                  if ((QuantaProduto = $31) and (QuantaTracking[Contador].Viola_Bateria)) or
                     (QuantaTracking[Contador].Evento = 1) then
                     SqlExec := SqlExec +  '1, '
                  Else
                     SqlExec := SqlExec +  '0, ';

                  //Bateria Violada
                  if QuantaTracking[Contador].Evento = 1  then
                     SqlExec := SqlExec +  '1' + ', '
                  Else
                     SqlExec := SqlExec +  '0' + ', ';

                  //Bateria Religada
                  if QuantaTracking[Contador].Evento = 4 then
                     SqlExec := SqlExec +  '1' + ', '
                  Else
                     SqlExec := SqlExec +  '0' + ', ';

                  //Trata Produto -> Marca_codigo
                  If QuantaProduto = $31 Then
                     SqlExec := SqlExec + '34' + ', '
                  Else
                     SqlExec := SqlExec + '35' + ', ';

                  //Produto
                  SqlExec := SqlExec + IntToStr(QuantaProduto) + ', ';

                  //versao
                  SqlExec := SqlExec + IntToStr(QuantaVersao) + ', ';

                  //Data Jammer (o jammer é tratado por data)
                  if (QuantaTracking[Contador].Jammer) Then
                     SqlExec := SqlExec + 'DATE_SUB( ' +
                       QuotedStr(FormatDateTime('yyyy-mm-dd hh:nn:ss',
                       QuantaTracking[Contador].dh_violacao)) +
                       ' ,INTERVAL  hour(timediff(now(),utc_timestamp())) Hour)); '
                  Else
                     SqlExec := SqlExec + 'null);';

   //               //BreakDown1 -- Evento Interno
   //               SqlExec :=  SqlExec + IntToStr(QuantaTracking[Contador].Evento) + ',' ;
   //
   //               //BreakDown2 -- Evento Quanta
   //               SqlExec :=  SqlExec + IntToStr(Strtoint('$' + Copy(IntToHex(QuantaTracking[Contador].EventoQuanta,4),1,2))) + ',' ;
   //
   //               //BreakDown3 -- Evento Quanta
   //               SqlExec :=  SqlExec + IntToStr(Strtoint('$' + Copy(IntToHex(QuantaTracking[Contador].EventoQuanta,4),3,2))) ;
   //

                  SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);

                  if QuantaTracking[Contador].Evento = 4 then
                  Begin
                     SqlExec := 'call recebe_parametros_cpr(';
                     SqlExec := SqlExec + QuotedStr(Processar.FieldByName('ID').AsString) + ', ';
                     SqlExec := SqlExec + QuotedStr('BATERIA') + ',' +
                        QuotedStr('RELIGADA') + '); ';
                     SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                  End;

                  if QuantaTracking[Contador].Evento = 1 then
                  Begin
                     SqlExec := 'call recebe_parametros_cpr(';
                     SqlExec := SqlExec + QuotedStr(Processar.FieldByName('ID').AsString) + ', ';
                     SqlExec := SqlExec + QuotedStr('BATERIA') + ',' +
                        QuotedStr('VIOLADA') + '); ';
                     SqlPendente := SqlPendente + SqlExec + Char(13) + Char(10);
                  End;

               Except
                  SalvaLog(Arq_Log, 'Erro ao Gerar Sql Tread Id: ' + InttoStr(ThreadId) + ': ' + SqlExec);
               End;
            End;
         End;

         if (ErroDecode > 0) or (length(QuantaTracking) = 0) or (Processar.FieldByName('ID').AsString = Debug_ID) then
         Begin

            Try
               PacketStr := '';
               for Contador := 0 to Length(PacketTot) - 1 do
                  PacketStr := PacketStr + IntToHex(PacketTot[Contador], 2);
               SqlExec      := 'Insert into acp245.quanta_recebido Values(';
               SqlExec      := SqlExec + QuotedStr(Processar.FieldByName('ID').AsString ) + ', ';
               SqlExec      := SqlExec + 'now(),';
               SqlExec      := SqlExec + InttoStr(QuantaProduto) + ',';
               SqlExec      := SqlExec + InttoStr(QuantaTipo) + ',';
               SqlExec      := SqlExec + 'INET_ATON(' + QuotedStr(Processar.FieldByName('IP').AsString) + '),';
               SqlExec      := SqlExec + QuotedStr(PacketStr) + ');';
               SqlPendente  := SqlPendente + SqlExec + Char(13) + Char(10);
            Except
               SalvaLog(Arq_Log, 'Pacote a ser decodificado: ZERADO !!!');
            End;

         End;

         //Limpa os tracking do vetor
         SetLength(QuantaTracking,0);

         Processar.Next;

      End;
   Except
      SalvaLog(Arq_Log, 'Erro no looping (Processar.Eof): ' + InttoStr(ThreadId));
   End;

//   tFinal := now;

   Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_inbox);
   Arq_Err   := DirErros + '\' + ExtractFileName(Arq_inbox);
   Arq_Sql   := DirSql + '\' + ExtractFileName(Arq_inbox);

//   tInicio := now;

   SalvaArquivo(Arq_Sql, SqlPendente);

//   tFinal := now;

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
      Processar.SaveToFile(Arq_Err);
      SalvaLog(Arq_Log, 'Erro ao Deletar recebidos: ' + Arq_inbox);
   End;

   Sleep(50);

except
   SalvaLog(Arq_Log, 'Erro na Procedure: GravaTracking');
end;
End;

Function gravacao_quanta.DecodeQuanta(pProduto,pTipo: Byte):Boolean;
var NumTracks: SmallInt;
Var Posicao:   SmallInt;
Var Contador:  SmallInt;
Begin

   Result := True;

   Try
      //Radar Duo
      if pProduto = $31 then
      Begin
         //Tracking - Tabela de Estado
         if pTipo in [$4C,$4D]  then
         Begin
            //Posicao Inicial do Pacote depois do Header = 15
            //Posicao de Quantidade de tabelas enviadas nesta mensagem (N) = 19
            Posicao       := 18; //Comeca no Zero !!!
            NumTracks     := (PacketTot[Posicao] * 256) + PacketTot[Posicao+1];
            Posicao       := 22; //Comeca no Zero !!!
            for Contador  := 1 to NumTracks do
            Begin
               if (Debug In [2, 5, 9]) Then
                  SalvaLog(Arq_Log, 'Vai Decodificar: ' + InttoStr(Contador) +  '/' + InttoStr(NumTracks) );
               Posicao := Decode_31_4C(Posicao);
            End;
         End
         Else
         Begin
            ErroDecode := ErroDecode +1;
            Result := False;
         End;
      End
      else if (pProduto = $50) and (pTipo in [$07,$12]) then
      Begin
         //Posicao Inicial do Pacote depois do Header = 15
         //Posicao de Quantidade de tabelas enviadas nesta mensagem (N) = 19
         Posicao       := 18; //Comeca no Zero !!!
         NumTracks     := (PacketTot[Posicao] * 256) + PacketTot[Posicao+1];
         Posicao       := 22; //Comeca no Zero !!!
         for Contador  := 1 to NumTracks do
         Begin
            if (Debug In [2, 5, 9]) Then
               SalvaLog(Arq_Log, 'Vai Decodificar: ' + InttoStr(Contador) +  '/' + InttoStr(NumTracks) );
            Posicao := Decode_50_12(Posicao);
         End;
      End
      else if pProduto in [$40,$41,$42,$50,$57,$58] then
      Begin
         if pTipo in [$0D,$0E]  then
         Begin
            //Posicao Inicial do Pacote depois do Header = 15
            //Posicao de Quantidade de tabelas enviadas nesta mensagem (N) = 19
            Posicao       := 18; //Comeca no Zero !!!
            NumTracks     := (PacketTot[Posicao] * 256) + PacketTot[Posicao+1];
            Posicao       := 22; //Comeca no Zero !!!
            for Contador  := 1 to NumTracks do
            Begin
               if (Debug In [2, 5, 9]) Then
                  SalvaLog(Arq_Log, 'Vai Decodificar: ' + InttoStr(Contador) +  '/' + InttoStr(NumTracks) );
               Posicao := Decode_99_0D(Posicao);
            End;
         End
         Else if pTipo in [$07,$12,$13]  then
         Begin
            //Posicao Inicial do Pacote depois do Header = 15
            //Posicao de Quantidade de tabelas enviadas nesta mensagem (N) = 19
            Posicao       := 18; //Comeca no Zero !!!
            NumTracks     := (PacketTot[Posicao] * 256) + PacketTot[Posicao+1];
            Posicao       := 22; //Comeca no Zero !!!
            for Contador  := 1 to NumTracks do
            Begin
               if (Debug In [2, 5, 9]) Then
                  SalvaLog(Arq_Log, 'Vai Decodificar: ' + InttoStr(Contador) +  '/' + InttoStr(NumTracks) );
               Posicao := Decode_99_12(Posicao);
            End;
         End
         Else
         Begin
            ErroDecode := ErroDecode +1;
            Result     := False;
         End;
      End;
   Except
      ErroDecode := ErroDecode +1;
      Result     := False;
   End;

End;

{Decode do produto 31 - pacote 4C ou 4D}
Function gravacao_quanta.Decode_31_4C(var pInicio: SmallInt): SmallInt;
Var Tam_bitfield: Byte;
    Tam_Tabela:   SmallInt;
    BitField:     Array Of Boolean;
    NumTracks:    SmallInt;
    Contador:     SmallInt;
    Evento:       SmallInt;
    StrTmp:       String;
    PosFinal:     SmallInt;
Begin
Try
   PosFinal     := pInicio;
   NumTracks    := Length(QuantaTracking);
   SetLength(QuantaTracking,NumTracks+1);
   Evento       := (PacketTot[pInicio] * 256) + PacketTot[pInicio+1];
   QuantaTracking[NumTracks].EventoQuanta := Evento;
   QuantaTracking[NumTracks].Evento       := Busca_evento(QuantaProduto,Evento);


   pInicio      := pInicio + 2;


   Tam_bitfield := PacketTot[pInicio];

   pInicio      := pInicio + 1;

   If Tam_bitfield < 5 Then
      SetLength(BitField,5*8)
   Else
      SetLength(BitField,Tam_bitfield*8);

   if (Debug In [2, 5, 9]) Then
      SalvaLog(Arq_Log, 'Tamanho do Bit Fields: ' + InttoStr(Tam_bitfield));

   for Contador  := 0 to Tam_bitfield-1 do
   Begin

      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Bit Fields[' + InttoStr(Contador) + ']: $' + InttoHex(PacketTot[pInicio],2));

      if ((PacketTot[pInicio]) and (1 shl 0)) <> 0 then
         BitField[(Contador*8)]   := True;
      if ((PacketTot[pInicio]) and (1 shl 1)) <> 0 then
         BitField[(Contador*8)+1]   := True;
      if ((PacketTot[pInicio]) and (1 shl 2)) <> 0 then
         BitField[(Contador*8)+2]   := True;
      if ((PacketTot[pInicio]) and (1 shl 3)) <> 0 then
         BitField[(Contador*8)+3]   := True;
      if ((PacketTot[pInicio]) and (1 shl 4)) <> 0 then
         BitField[(Contador*8)+4]   := True;
      if ((PacketTot[pInicio]) and (1 shl 5)) <> 0 then
         BitField[(Contador*8)+5]   := True;
      if ((PacketTot[pInicio]) and (1 shl 6)) <> 0 then
         BitField[(Contador*8)+6]   := True;
      if ((PacketTot[pInicio]) and (1 shl 7)) <> 0 then
         BitField[(Contador*8)+7]   := True;

      Inc(pInicio);
   End;

   Tam_Tabela   := (PacketTot[pInicio] * 256) + PacketTot[pInicio+1];
   pInicio      := pInicio + 2;
   if (Debug In [2, 5, 9]) Then
      SalvaLog(Arq_Log, 'Tamanho da Tabela: ' + InttoStr(Tam_Tabela));
   //Salva o tamanho total em caso de erro
   PosFinal     := PosFinal + Tam_Tabela;

   //Campo 0 - Time stamp do momento do evento que gerou a violação
   if (BitField[0]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_violacao := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Time stamp: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 0: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 1 - Time stamp da última posição válida (GPS).
   if (BitField[1]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_gps := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'última posição válida: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 1: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 2 - Latitude expressa em centésimos de segundo.
   if (BitField[2]) then
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Latitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Latitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 2: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 3 - Longitude expressa em centésimos de segundo
   if (BitField[3]) then
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Longitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Longitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 3: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 4 - Velocidade lida do GPS em km/h
   if (BitField[4]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Velocidade := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Velocidade: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 4: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 5 - Angulo de Deslocamento GPS
   if (BitField[5]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Angulo := Round(StrToIntDef(StrTmp,0)/10);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Angulo: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 5: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;


   //Campo 6 - Altitude
   if (BitField[6]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Altitude := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Altitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 6: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 7 - GPS Quality (N° de Satélites visíveis + 0 – Posição Válida; 1 – Imprecisa
   if (BitField[7]) then
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,1);
      QuantaTracking[NumTracks].Num_Satelites  := BinToInt(Copy(StrTmp,1,4));
      if StrToIntDef(Copy(StrTmp,8,1),0) = 0 then
         QuantaTracking[NumTracks].Posicao_valida := 1
      else
         QuantaTracking[NumTracks].Posicao_valida := 0;

      //Não Precisa
      //pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'N° de Satélites visíveis/Posição Válida: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 7: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 8 - Estado das entradas mapeadas bit a bit
   if (BitField[8]) then
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      if Copy(StrTmp,29,1) = '1'  then
         QuantaTracking[NumTracks].Jammer := True;
      if Copy(StrTmp,30,1) = '1'  then
         QuantaTracking[NumTracks].Acelerômetro := True;

      if Copy(StrTmp,31,1) = '1'  then
         QuantaTracking[NumTracks].Viola_Bateria := True
      Else
         QuantaTracking[NumTracks].Viola_bateria := False;

      if Copy(StrTmp,32,1) = '1'  then
         QuantaTracking[NumTracks].Ignicao := True;

      //Não Precisa
      //pInicio := pInicio + 4; //1 bytes lidos
      if (Debug In [2, 5, 9]) or (Processar.FieldByName('ID').AsString = Debug_ID) Then
         SalvaLog(Arq_Log, 'Estado das entradas: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 8: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 9 - Estado das saídas mapeadas bit a bit
   //Não Processa
   if (BitField[9]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 10 - Reservado
   //Não Processa
   if (BitField[10]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 11 - Reservado
   //Não Processa
   if (BitField[11]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 12 - Reservado
   //Não Processa
   if (BitField[12]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 13 - Reservado
   //Não Processa
   if (BitField[13]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 14 - Reservado
   //Não Processa
   if (BitField[14]) then
      pInicio := pInicio + 2; //2 bytes lidos

   //Campo 15 - Odômetro por GPS – décimos de Km
   if (BitField[15]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].Odometro := StrToIntDef(StrTmp,0);
      if QuantaTracking[NumTracks].Odometro < 0  then
         QuantaTracking[NumTracks].Odometro := 0;

      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Odômetro: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 15: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 16 - Reservado
   //Não Processa
   if (BitField[16]) then
      pInicio := pInicio + 4; //4 bytes lidos
   //Campo 17 - Reservado
   //Não Processa
   if (BitField[17]) then
      pInicio := pInicio + 1; //1 bytes lidos

   //Campo 18 - Tensão da bateria principal em volts 0x0D
   if (BitField[18]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2);
      QuantaTracking[NumTracks].Tensao := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 1; //1 byte lido
      //Ajuste de flag de bateria
      if (QuantaTracking[NumTracks].Viola_bateria) and
         ((QuantaTracking[NumTracks].Tensao <=2 ) or (QuantaTracking[NumTracks].Tensao > 5)) then
         QuantaTracking[NumTracks].Viola_bateria := False;

      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Tensão da bateria principal: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 18: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 19 - Tensão da bateria backup em décimos de volt 0x27
   //Não Processa
   if (BitField[19]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2);
      QuantaTracking[NumTracks].Tensao_Backup := Round(StrToIntDef(StrTmp,0)/10);
      pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Tensão da bateria backup: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 19: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 20 - Reservado
   //Não Processa
   if (BitField[20]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 21 - Reservado
   //Não Processa
   if (BitField[21]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 22 - Reservado
   //Não Processa
   if (BitField[22]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 23 - Reservado
   //Não Processa
   if (BitField[23]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 24 - Reservado
   //Não Processa
   if (BitField[24]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 25 - Reservado
   //Não Processa
   if (BitField[25]) then
      pInicio := pInicio + 1; //1 bytes lidos

   //Campo 26 - Nível do sinal (RSSI) – Valor do RSSI como é lido do modem (0...31)
   //Não Processa
   if (BitField[26]) then
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],1);
      QuantaTracking[NumTracks].RSSI := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Nível do sinal (RSSI) : ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Campo 26: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Campo 27 - Reservado
   //Não Processa
   if (BitField[27]) then
      pInicio := pInicio + 1; //2 bytes lidos
   //Campo 28 - Reservado
   //Não Processa
   if (BitField[28]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 29 - Reservado
   //Não Processa
   if (BitField[29]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 30 - Reservado
   //Não Processa
   if (BitField[30]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 31 - Reservado
   //Não Processa
   if (BitField[31]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 32 - Reservado
   //Não Processa
   if (BitField[32]) then
      pInicio := pInicio + 2; //2 bytes lidos
   //Campo 33 - Reservado
   //Não Processa
   if (BitField[33]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 34 - Reservado
   //Não Processa
   if (BitField[34]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 35 - Reservado
   //Não Processa
   if (BitField[35]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 36 - Reservado
   //Não Processa
   if (BitField[36]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 37 - Reservado
   //Não Processa
   if (BitField[37]) then
      pInicio := pInicio + 1; //1 bytes lidos
   //Campo 38 - Reservado
   //Não Processa
   if (BitField[38]) then
      pInicio := pInicio + 1; //1 bytes lidos

   Result := pInicio;
Except
   SalvaLog(Arq_Log, 'Erro no Decode: 31_4C' + StrTmp );
End;
End;

{Decode dos produtos $40,$41,$42,$50,$57,$58}
Function gravacao_quanta.Decode_99_0D(var pInicio: SmallInt): SmallInt;
Var    NumTracks:  SmallInt;
    Evento:     SmallInt;
    StrTmp:     String;
    PosFinal:   SmallInt;
Begin
Try
   PosFinal     := pInicio + 46;

   if PosFinal > length(PacketTot) then
      SalvaLog(Arq_Log, 'Erro Tamanho do Pacote: ');

   NumTracks    := Length(QuantaTracking);
   SetLength(QuantaTracking,NumTracks+1);
   //Evento
   Evento       := (PacketTot[pInicio] * 256) + PacketTot[pInicio+1];
   QuantaTracking[NumTracks].EventoQuanta := Evento;
   QuantaTracking[NumTracks].Evento       := Busca_evento(QuantaProduto,Evento);

   pInicio      := pInicio + 2;


   //Byte 2-3-4-5 - Time stamp do momento do evento que gerou a violação
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_violacao := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Time stamp: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 2-3-4-5: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 6-7-8-9 - Time stamp da última posição válida (GPS).
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_gps := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'última posição válida: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 6-7-8-9 : ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 10-11-12-13- Latitude expressa em centésimos de segundo.
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Latitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Latitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 10-11-12-13: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 14-15-16-17 - Longitude expressa em centésimos de segundo
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Longitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Longitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 14-15-16-17: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 18-19 - Velocidade lida do GPS em km/h
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Velocidade := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Velocidade: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 18-19: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 20-21 - Angulo de Deslocamento GPS
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Angulo := Round(StrToIntDef(StrTmp,0)/10);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Angulo: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 20-21: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;


   //Byte 22-23 - Altitude
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Altitude := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Altitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no CByte 22-23: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 24 - GPS Quality (N° de Satélites visíveis + 0 – Posição Válida; 1 – Imprecisa
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,1);
      QuantaTracking[NumTracks].Num_Satelites  := BinToInt(Copy(StrTmp,1,4));
      if StrToIntDef(Copy(StrTmp,8,1),0) = 0 then
         QuantaTracking[NumTracks].Posicao_valida := 1
      else
         QuantaTracking[NumTracks].Posicao_valida := 0;

      //Não Precisa
      //pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'N° de Satélites visíveis/Posição Válida: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 24: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 25-26-27-28 - Estado das entradas mapeadas bit a bit
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      if (Copy(StrTmp,16,1) = '1') and (QuantaProduto <> $40)  then
         QuantaTracking[NumTracks].Viola_bateria := True
      Else
         QuantaTracking[NumTracks].Viola_bateria := False;
      if Copy(StrTmp,32,1) = '1'  then
         QuantaTracking[NumTracks].Ignicao := True;

      //Não Precisa
      //pInicio := pInicio + 4; //1 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Estado das entradas: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 25-26-27-28: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 29-30 - Estado das saídas mapeadas bit a bit
   pInicio := pInicio + 2; //2 bytes lidos

   //Byte 31-32 - RPM
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].RPM := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'RPM: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 31-32: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;


   //Byte 33-34 - Velocidade lida do Tacógrafo (em Hz)
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Vel_Tacografo := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Velocidade Tacógrafo: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 33-34: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 35-36-37-38 - Odômetro por GPS – décimos de Km
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].Odometro := StrToIntDef(StrTmp,0);
      if QuantaTracking[NumTracks].Odometro < 0  then
         QuantaTracking[NumTracks].Odometro := 0;
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Odômetro: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 35-36-37-38: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 39 - Status da comunicação
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,1);
      QuantaTracking[NumTracks].RSSI := BinToInt(Copy(StrTmp,5,4));
      //Não Precisa
      //pInicio := pInicio + 1; //1 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Estado da comunicação: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 39: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 40 - SNR do Satélite em dB
   //Não Precisa
   pInicio := pInicio + 1; //1 byte lido

   //Byte 41 - Tensão da bateria principal em volts 0x0D
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2);
      QuantaTracking[NumTracks].Tensao := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Tensão da bateria principal: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 41: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 42 - Tensão da bateria backup em décimos de volt 0x27
   //Não Processa
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2);
      QuantaTracking[NumTracks].Tensao_Backup := Round(StrToIntDef(StrTmp,0)/10);
      pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Tensão da bateria backup: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 42: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 43 - Sensor de temperatura 1
   //Não Processa
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2);
      QuantaTracking[NumTracks].Temperatura := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Sensor de temperatura 1: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 43: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 44 - Sensor de temperatura 2
   //Não Processa
    pInicio := pInicio + 1; //1 bytes lidos

   //Byte 45 - Sensor de temperatura 3
   //Não Processa
    pInicio := pInicio + 1; //1 bytes lidos

    Result := pInicio;
except

   SalvaLog(Arq_Log, 'Erro no Decode 99_0D: ' + StrTmp );

End;
End;


{Decode dos produtos $40,$41,$42,$50,$57,$58}
{Tabela de Tracking}
Function gravacao_quanta.Decode_99_12(var pInicio: SmallInt): SmallInt;
Var //Tam_Tabela: SmallInt;
    NumTracks:  SmallInt;
    //Contador:   SmallInt;
    Evento:     SmallInt;
    StrTmp:     String;
    PosFinal:   SmallInt;
Begin
Try
   Result       := pInicio;

   PosFinal     := pInicio + 40;

   if PosFinal > length(PacketTot) then
      SalvaLog(Arq_Log, 'Erro Tamanho do Pacote: ');

   NumTracks    := Length(QuantaTracking);
   SetLength(QuantaTracking,NumTracks+1);
   //Evento
   Evento       := (PacketTot[pInicio] * 256) + PacketTot[pInicio+1];
   QuantaTracking[NumTracks].EventoQuanta := Evento;
   QuantaTracking[NumTracks].Evento       := Busca_evento(QuantaProduto,Evento);

   pInicio      := pInicio + 2;


   //Byte 2-3-4-5 - Time stamp do momento do evento que gerou a violação
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_violacao := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Time stamp: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 2-3-4-5: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 6-7-8-9 - Time stamp da última posição válida (GPS).
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_gps := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'última posição válida: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 6-7-8-9 : ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 10-11-12-13- Latitude expressa em centésimos de segundo.
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Latitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Latitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 10-11-12-13: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 14-15-16-17 - Longitude expressa em centésimos de segundo
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Longitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Longitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 14-15-16-17: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 18-19 - Velocidade lida do GPS em km/h
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Velocidade := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Velocidade: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 18-19: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 20-21 - Angulo de Deslocamento GPS
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Angulo := Round(StrToIntDef(StrTmp,0)/10);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Angulo: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 20-21: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;


   //Byte 22-23 - Altitude
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Altitude := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Altitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 22-23: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 24 - GPS Quality (N° de Satélites visíveis + 0 – Posição Válida; 1 – Imprecisa
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,1);
      QuantaTracking[NumTracks].Num_Satelites  := BinToInt(Copy(StrTmp,1,4));
      if StrToIntDef(Copy(StrTmp,8,1),0) = 0 then
         QuantaTracking[NumTracks].Posicao_valida := 1
      else
         QuantaTracking[NumTracks].Posicao_valida := 0;

      //Não Precisa
      //pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'N° de Satélites visíveis/Posição Válida: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 24: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 25-26-27-28 - Estado das entradas mapeadas bit a bit
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      if (Copy(StrTmp,16,1) = '1') and (QuantaProduto <> $40)  then
         QuantaTracking[NumTracks].Viola_bateria := True
      Else
         QuantaTracking[NumTracks].Viola_bateria := False;
      if Copy(StrTmp,32,1) = '1'  then
         QuantaTracking[NumTracks].Ignicao := True;

      //Não Precisa
      //pInicio := pInicio + 4; //1 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Estado das entradas: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 25-26-27-28: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 29-30 - Estado das saídas mapeadas bit a bit
   pInicio := pInicio + 2; //2 bytes lidos

   //Byte 31-32 - RPM
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].RPM := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'RPM: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 31-32: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;


   //Byte 33-34 - Velocidade lida do Tacógrafo (em Hz)
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Vel_Tacografo := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Velocidade Tacógrafo: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 33-34: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 35-36-37-38 - Odômetro por GPS – décimos de Km
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].Odometro := StrToIntDef(StrTmp,0);
      if QuantaTracking[NumTracks].Odometro < 0  then
         QuantaTracking[NumTracks].Odometro := 0;
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Odômetro: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 35-36-37-38: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
   End;

   //Byte 39 - Status da comunicação
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,1);
      QuantaTracking[NumTracks].RSSI := BinToInt(Copy(StrTmp,5,4));
      //Não Precisa
      //pInicio := pInicio + 1; //1 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Estado da comunicação: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 39: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
   End;

   Result := pInicio;
Except
   SalvaLog(Arq_Log, 'Erro no Decode 99_12: ' + StrTmp );
End;
End;


{Decode dos produtos $50}
{Tabela de Tracking}
Function gravacao_quanta.Decode_50_12(var pInicio: SmallInt): SmallInt;
Var NumTracks:  SmallInt;
    Evento:     SmallInt;
    StrTmp:     String;
    PosFinal:   SmallInt;
Begin
Try
   Result       := pInicio;

   PosFinal     := pInicio + 38;

   if PosFinal > length(PacketTot) then
      SalvaLog(Arq_Log, 'Erro Tamanho do Pacote: ');

   NumTracks    := Length(QuantaTracking);
   SetLength(QuantaTracking,NumTracks+1);
   //Evento
   Evento       := (PacketTot[pInicio] * 256) + PacketTot[pInicio+1];
   QuantaTracking[NumTracks].EventoQuanta := Evento;
   QuantaTracking[NumTracks].Evento       := Busca_evento(QuantaProduto,Evento);

   pInicio      := pInicio + 2;


   //Byte 2-3-4-5 - Time stamp do momento do evento que gerou a violação
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_violacao := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Time stamp: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 2-3-4-5: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 6-7-8-9 - Time stamp da última posição válida (GPS).
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2)
                     + InttoHex(PacketTot[pInicio+2],2)
                     + InttoHex(PacketTot[pInicio+3],2);
      QuantaTracking[NumTracks].dh_gps := TimeStamptoDateTime(StrToInt64Def(StrTmp,0));
      pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'última posição válida: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 6-7-8-9 : ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 10-11-12-13- Latitude expressa em centésimos de segundo.
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Latitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Latitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 10-11-12-13: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 14-15-16-17 - Longitude expressa em centésimos de segundo
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      QuantaTracking[NumTracks].Longitude := CompTwoToLatLong(StrTmp)*10;
      //Não Precisa
      //pInicio := pInicio + 4; //4 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Longitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 14-15-16-17: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 18-19 - Velocidade lida do GPS em km/h
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Velocidade := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Velocidade: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 18-19: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 20-21 - Angulo de Deslocamento GPS
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Angulo := Round(StrToIntDef(StrTmp,0)/10);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Angulo: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 20-21: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;


   //Byte 22-23 - Altitude
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Altitude := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Altitude: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 22-23: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 24 - GPS Quality (N° de Satélites visíveis + 0 – Posição Válida; 1 – Imprecisa
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,1);
      QuantaTracking[NumTracks].Num_Satelites  := BinToInt(Copy(StrTmp,1,4));
      if StrToIntDef(Copy(StrTmp,8,1),0) = 0 then
         QuantaTracking[NumTracks].Posicao_valida := 1
      else
         QuantaTracking[NumTracks].Posicao_valida := 0;

      //Não Precisa
      //pInicio := pInicio + 1; //1 byte lido
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'N° de Satélites visíveis/Posição Válida: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 24: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 25-26-27-28 - Estado das entradas mapeadas bit a bit
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,4);
      if Copy(StrTmp,16,1) = '1'  then
         QuantaTracking[NumTracks].Viola_bateria := True
      Else
         QuantaTracking[NumTracks].Viola_bateria := False;
      if Copy(StrTmp,32,1) = '1'  then
         QuantaTracking[NumTracks].Ignicao := True;

      //Não Precisa
      //pInicio := pInicio + 4; //1 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Estado das entradas: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 25-26-27-28: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 29-30 - Estado das saídas mapeadas bit a bit
   pInicio := pInicio + 2; //2 bytes lidos

   //Byte 31-32 - RPM
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].RPM := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'RPM: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 31-32: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;


   //Byte 33-34 - Velocidade lida do Tacógrafo (em Hz)
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Vel_Tacografo := StrToIntDef(StrTmp,0);
      pInicio := pInicio + 2; //2 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Velocidade Tacógrafo: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 33-34: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
      SetLength(QuantaTracking,0);
      Exit;
   End;

   //Byte 35-36 - Odômetro por GPS – décimos de Km
   Try
      StrTmp  := '$' + InttoHex(PacketTot[pInicio],2)
                     + InttoHex(PacketTot[pInicio+1],2);
      QuantaTracking[NumTracks].Odometro := StrToIntDef(StrTmp,0);
      if QuantaTracking[NumTracks].Odometro < 0  then
         QuantaTracking[NumTracks].Odometro := 0;
      pInicio := pInicio + 2 ; //2 bytes lidos PULO DO GATO
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Odômetro: ' + StrTmp);
   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 35-36: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
   End;

   //Byte 37 - Status da comunicação
   Try
      StrTmp  := CharToStrBin(PacketTot, pInicio,1);
      QuantaTracking[NumTracks].RSSI := BinToInt(Copy(StrTmp,5,4));
      //Não Precisa
      //pInicio := pInicio + 1; //1 bytes lidos
      if (Debug In [2, 5, 9]) Then
         SalvaLog(Arq_Log, 'Estado da comunicação: ' + StrTmp);

   except
      ErroDecode := ErroDecode +1;
      SalvaLog(Arq_Log, 'Erro no Byte 37: ' + StrTmp + ' - Tracking:' + InttoStr(NumTracks));
   End;

   Result := pInicio;
Except
   SalvaLog(Arq_Log, 'Erro no Decode:    50_12');
End;
End;

Procedure gravacao_quanta.Dormir(pTempo: SmallInt);
Var
   Contador: SmallInt;
   // Roda o Sleep em slice de 1/20 para checar o Final da thread
Begin
   For Contador := 1 to 20 do
   Begin
      if Not Encerrar then
         Sleep(Trunc(pTempo / 20));
   End
End;



Function gravacao_quanta.Busca_evento(pProduto,pevento: SmallInt): SmallInt;
Var Contador :SmallInt;
Begin

   Result := 9;

   if pProduto <> $31 then
      pProduto := $99;

   for Contador  := 0 to Length(QuantaEventos)-1 do
   Begin
      If (QuantaEventos[Contador].Produto = pProduto) And
         (QuantaEventos[Contador].Evento  = pevento) Then
         Result := QuantaEventos[Contador].Evento_interno;
   End;

   If (Debug In [2, 5, 9]) or (Processar.FieldByName('ID').AsString = Debug_ID) Then
      SalvaLog(Arq_Log,'ID: ' + Processar.FieldByName('ID').AsString +  Chr(13) +
                       'Produto: ' + InttoStr(pProduto)  +  Chr(13) +
                       'Evento: ' + InttoStr(pevento)  +  Chr(13) +
                       ' - Evento recebido: ' + InttoStr(Result));

End;

end.

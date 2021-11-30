unit thread_resultado;

interface

uses
   Windows, SysUtils, Classes, Math, ZConnection,
   DB, DBClient, Types, DateUtils,
   FuncColetor, FunAcp;

type
   resultado = class(TThread)

   public

      // Parametros recebidos
      Arq_Log: String;
      DirProcess: String;
      Encerrar: Boolean;
      ServerStartUp: tDateTime;
      ThreadId: Word;

      Arq_resultados: String;

   private
      Processado: tClientDataSet;

      { Private declarations }
   protected

      procedure Execute; override;
      Function BuscaArquivo: String;
      Procedure LerResultados;

   end;

implementation

Uses Gateway_01;

// Execucao da Thread em si.
procedure resultado.Execute;
begin

   Processado := tClientDataSet.Create(nil);
   Processado.FieldDefs.Add('Tcp_Client', ftInteger, 0, False);
   Processado.FieldDefs.Add('IP', ftString, 15, False);
   Processado.FieldDefs.Add('Porta', ftInteger, 0, False);
   Processado.FieldDefs.Add('ID', ftString, 20, False);
   Processado.FieldDefs.Add('Resposta', ftBlob, 0, False);
   Processado.CreateDataSet;

   while Not Encerrar do
   Begin

      TcpSrvForm.Thresultado_ultimo := Now;

      Arq_resultados := BuscaArquivo;

      if (Arq_resultados <> '') then
         Synchronize(LerResultados)
      Else
         Sleep(500);

   End;

   Processado.Free;

   Self.Free;

end;

Function resultado.BuscaArquivo: String;
Var
   Arquivos: TSearchRec;
Begin

   Arq_resultados := '';

   if FindFirst(DirProcess + '\*.ACP' + FormatFloat('00', ThreadId), faArchive,
      Arquivos) = 0 then
   begin

      Arq_resultados := DirProcess + '\' + Arquivos.Name;

   End;

   FindClose(Arquivos);

   Result := Arq_resultados;
   Sleep(50);

End;

Procedure resultado.LerResultados;
Var
   Arq_Proce: String;
   Erros: Boolean;
   blobF: TBlobField;
   StreamRes: TMemoryStream;
   // Msg        : String;
   // PacketRes  : TByteDynArray;
   // Contador   : Word;
   FileDate: tDateTime;
   StrTmp: String;

Begin

   Erros := False;

   StrTmp := ExtractFileName(Arq_resultados);
   Try
      FileDate := EncodeDateTime(StrtoInt(Copy(StrTmp, 1, 4)),
         StrtoInt(Copy(StrTmp, 6, 2)), StrtoInt(Copy(StrTmp, 9, 2)),
         StrtoInt(Copy(StrTmp, 12, 2)), StrtoInt(Copy(StrTmp, 15, 2)),
         StrtoInt(Copy(StrTmp, 18, 2)), 0);
   Except
      FileDate := Now;
   End;

   Try
      Processado.LoadFromFile(Arq_resultados);
   Except
      SalvaLog(Arq_Log, 'Arquivo não Encontrado: ' + Arq_resultados);
      Exit;
   End;

   Processado.First;

   while Not Processado.Eof do
   Begin
      if TcpSrvForm <> nil then

         Try
            if (((Now - FileDate) * 60 * 24) <= 5) and (Now > ServerStartUp)
            then
            Begin
               Try
                  StreamRes := TMemoryStream.Create;
                  blobF := Processado.FieldByName('Resposta') as TBlobField;
                  blobF.SaveToStream(StreamRes);
                  TcpSrvForm.RecebeResultado(Processado.FieldByName('ID')
                     .AsString, Processado.FieldByName('tcp_client').AsInteger,
                     Processado.FieldByName('IP').AsString,
                     Processado.FieldByName('PORTA').AsString, StreamRes);

               finally
                  StreamRes.Free;
               end;
            End;
            Processado.Delete;
         Except

            Erros := True;
            SalvaLog(Arq_Log, 'Erro Atualizar Servidor: ' + Arq_resultados);
            Processado.Next;

         End;

   End;

   Processado.Close;

   Arq_Proce := DirProcess + '\' + ExtractFileName(Arq_resultados);

   if Not Erros then
      Try
         deletefile(Arq_resultados);
      Except
         SalvaLog(Arq_Log, 'Erro excluir arquivo: ' + Arq_resultados);
      End;

   Sleep(500);

End;

end.

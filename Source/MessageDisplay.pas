{******************************************************************************
 Description

 Product/Component Name : MessageDisplay
           File Version : 1.0
        Source Filename : MessageDisplay.pas
            Description : Renders received ntfy messages in descending date order

*****************************************************************************}

unit MessageDisplay;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Types,
  System.IOUtils,
  System.Net.HttpClient,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  Vcl.Dialogs,
  Vcl.Direct2D,
  MessagesList,
  NtfyEmoji,
  NtfyClient;

type
  TMessageData = MessagesList.TMessageData;

  TMessagePanel = class(TCustomControl)
  private
    FData: TMessageData;
    FAttachmentRect: TRect;
    FMeasureBitmap: TBitmap;
    FTitleLines: TStringList;
    FAttachmentLines: TStringList;
    FMessageLines: TStringList;
    FEmojis: TStringList;
    FIconWidth: Integer;
    FSecondaryWidth: Integer;
    FTextLeft: Integer;
    FTextWidth: Integer;
    procedure UpdateLayout;
    procedure UpdateCachedText;
    procedure DrawBackground(AD2DCanvas: TDirect2DCanvas);
    procedure DrawEmojis(AD2DCanvas: TDirect2DCanvas);
    procedure DrawTitle(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
    procedure DrawTimestamp(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
    procedure DrawPriority(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
    procedure DrawAttachment(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
    procedure DrawMessage(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
    function HasAttachmentLink: Boolean;
    function IsOverAttachment(X, Y: Integer): Boolean;
    procedure UpdateCursor(X, Y: Integer);
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseMove(Shift: TShiftState; X, Y: Integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
    procedure CMMouseLeave(var Message: TMessage); message CM_MOUSELEAVE;
  public
    constructor Create(AOwner: TComponent; AData: TMessageData); reintroduce;
    destructor Destroy; override;
    procedure RecalculateLayout;
  end;

  TMessageDisplay = class
  private
    FScrollBox: TScrollBox;
    FMessages: TMessagesList;
    FRebuildingPanels: Boolean;
    procedure RebuildPanels;
    procedure ScrollBoxResize(Sender: TObject);
  public
    constructor Create(AOwner: TComponent); overload;
    constructor Create(AOwner: TComponent; AScrollBox: TScrollBox); overload;
    destructor Destroy; override;
    procedure SetScrollBox(AScrollBox: TScrollBox);
    procedure ClearBrowser;
    procedure AddMessage(const aData: TMessageData);
    function GetScrollBox: TScrollBox;
  end;

implementation

const
  cPanelMargin = 16;
  cPanelPadding = 16;
  cIconColumnWidth = 42;
  cEmojiSpacing = 6;
  cTextSpacing = 6;
  cBottomDividerPadding = 10;
  cMinPanelHeight = 88;
  cEmojiFontSize = 20;
  cSecondaryEmojiFontSize = 14;
  cTitleFontSize = 11;
  cMetaFontSize = 10;
  cAttachmentFontSize = 10;
  cMessageFontSize = 9;

function NormalizeLineBreaks(const aText: string): string;
begin
  Result := StringReplace(aText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #10, sLineBreak, [rfReplaceAll]);
end;

function FormatAttachmentSize(const aBytes: Int64): string;
begin
  if aBytes <= 0 then
    Exit('');

  if aBytes >= 1024 * 1024 then
    Result := FormatFloat('0.0 MB', aBytes / (1024 * 1024))
  else if aBytes >= 1024 then
    Result := FormatFloat('0.0 KB', aBytes / 1024)
  else
    Result := IntToStr(aBytes) + ' bytes';
end;

function PriorityText(const aPriority: Integer): string;
begin
  case aPriority of
    cNtfyMaxPriority: Result := 'Max / urgent';
    cNtfyHighPriority: Result := 'High';
    cNtfyLowPriority: Result := 'Low';
    cNtfyMinPriority: Result := 'Min';
    cNtfyDefaultPriority,
    cNtfyNoPriority: Result := 'None';
  else
    Result := '';
  end;
end;

function PriorityColor(const aPriority: Integer): TColor;
begin
  case aPriority of
    cNtfyMaxPriority: Result := RGB(220, 20, 60);
    cNtfyHighPriority: Result := RGB(255, 140, 0);
    cNtfyLowPriority,
    cNtfyMinPriority: Result := RGB(169, 169, 169);
    cNtfyDefaultPriority,
    cNtfyNoPriority: Result := RGB(30, 144, 255);
  else
    Result := clGrayText;
  end;
end;

function AttachmentSummary(const aData: TMessageData): string;
var
  SizeText: string;
begin
  Result := '';
  if aData = nil then
    Exit;

  if aData.AttachmentName <> '' then
    Result := aData.AttachmentName
  else if aData.AttachmentURL <> '' then
    Result := aData.AttachmentURL;

  if Result = '' then
    Exit;

  SizeText := FormatAttachmentSize(aData.AttachmentSize);
  if SizeText <> '' then
    Result := Result + ' (' + SizeText + ')';

  Result := 'Attachment: ' + Result;
end;

function SuggestedAttachmentFileName(const aData: TMessageData): string;
var
  FileName: string;
  URL: string;
  QueryPos: Integer;
  SlashPos: Integer;
begin
  Result := 'attachment.bin';
  if aData = nil then
    Exit;

  FileName := Trim(aData.AttachmentName);
  if FileName = '' then
  begin
    URL := Trim(aData.AttachmentURL);
    QueryPos := Pos('?', URL);
    if QueryPos > 0 then
      URL := Copy(URL, 1, QueryPos - 1);
    SlashPos := LastDelimiter('/', URL);
    if SlashPos > 0 then
      FileName := Copy(URL, SlashPos + 1, MaxInt)
    else
      FileName := URL;
  end;

  FileName := Trim(FileName);
  if FileName <> '' then
    Result := TPath.GetFileName(FileName);
end;

procedure DownloadAttachmentToFile(const aURL, aFileName: string);
var
  HTTPClient: THTTPClient;
  Response: IHTTPResponse;
  FileStream: TFileStream;
begin
  HTTPClient := THTTPClient.Create;
  try
    try
      FileStream := TFileStream.Create(aFileName, fmCreate);
      try
        Response := HTTPClient.Get(aURL, FileStream);
      finally
        FileStream.Free;
      end;

      if (Response = nil) or (Response.StatusCode < 200) or (Response.StatusCode > 299) then
        raise Exception.CreateFmt('Attachment download failed: %s', [aURL]);
    except
      if TFile.Exists(aFileName) then
        TFile.Delete(aFileName);
      raise;
    end;
  finally
    HTTPClient.Free;
  end;
end;

function TMessagePanel.HasAttachmentLink: Boolean;
begin
  Result := (FData <> nil) and (Trim(FData.AttachmentURL) <> '');
end;

function TMessagePanel.IsOverAttachment(X, Y: Integer): Boolean;
begin
  Result := HasAttachmentLink and PtInRect(FAttachmentRect, Point(X, Y));
end;

procedure TMessagePanel.UpdateCursor(X, Y: Integer);
begin
  if IsOverAttachment(X, Y) then
    Cursor := crHandPoint
  else
    Cursor := crDefault;
end;

function TextLineHeight(ACanvas: TCanvas): Integer;
begin
  Result := ACanvas.TextHeight('Wg') + 1;
end;

procedure AddWrappedParagraph(ACanvas: TCanvas; ALines: TStrings; const AParagraph: string; const AMaxWidth: Integer);
var
  Words: TStringList;
  CurrentLine: string;
  Candidate: string;
  I: Integer;
begin
  if AParagraph = '' then
  begin
    ALines.Add('');
    Exit;
  end;

  Words := TStringList.Create;
  try
    ExtractStrings([' '], [], PChar(AParagraph), Words);
    if Words.Count = 0 then
    begin
      ALines.Add(AParagraph);
      Exit;
    end;

    CurrentLine := '';
    for I := 0 to Words.Count - 1 do
    begin
      if CurrentLine = '' then
        Candidate := Words[I]
      else
        Candidate := CurrentLine + ' ' + Words[I];

      if (AMaxWidth > 0) and (CurrentLine <> '') and (ACanvas.TextWidth(Candidate) > AMaxWidth) then
      begin
        ALines.Add(CurrentLine);
        CurrentLine := Words[I];
      end
      else
        CurrentLine := Candidate;
    end;

    if CurrentLine <> '' then
      ALines.Add(CurrentLine);
  finally
    Words.Free;
  end;
end;

procedure BuildWrappedLines(ACanvas: TCanvas; const AText: string; const AMaxWidth: Integer; ALines: TStrings);
var
  SourceLines: TStringList;
  I: Integer;
begin
  ALines.Clear;
  SourceLines := TStringList.Create;
  try
    SourceLines.Text := NormalizeLineBreaks(AText);
    if SourceLines.Count = 0 then
      SourceLines.Add('');

    for I := 0 to SourceLines.Count - 1 do
      AddWrappedParagraph(ACanvas, ALines, SourceLines[I], AMaxWidth);
  finally
    SourceLines.Free;
  end;
end;

procedure BuildEmojiParts(const ATagsCsv: string; AEmojis: TStrings);
var
  Tags: TStringList;
  I: Integer;
  TagText: string;
  Emoji: string;
begin
  AEmojis.Clear;
  if Trim(ATagsCsv) = '' then
    Exit;

  Tags := TStringList.Create;
  try
    Tags.CommaText := ATagsCsv;
    for I := 0 to Tags.Count - 1 do
    begin
      TagText := Trim(Tags[I]);
      if TagText = '' then
        Continue;

      Emoji := TagToEmoji(TagText);
      if (Emoji <> '') and (Emoji <> TagText) then
        AEmojis.Add(Emoji);
    end;
  finally
    Tags.Free;
  end;
end;

function PrimaryEmojiColumnWidth(AMeasureCanvas: TCanvas; AEmojis: TStrings): Integer;
var
  Width: Integer;
begin
  Result := cIconColumnWidth;
  if AEmojis.Count = 0 then
    Exit;

  AMeasureCanvas.Font.Name := 'Segoe UI Emoji';
  AMeasureCanvas.Font.Size := cEmojiFontSize;
  AMeasureCanvas.Font.Style := [];
  Width := AMeasureCanvas.TextWidth(AEmojis[0]);
  Result := Max(cIconColumnWidth, Width + cEmojiSpacing);
end;

function SecondaryEmojiRowWidth(AMeasureCanvas: TCanvas; AEmojis: TStrings): Integer;
var
  I: Integer;
begin
  Result := 0;
  if AEmojis.Count <= 1 then
    Exit;

  AMeasureCanvas.Font.Name := 'Segoe UI Emoji';
  AMeasureCanvas.Font.Size := cSecondaryEmojiFontSize;
  AMeasureCanvas.Font.Style := [];

  for I := 1 to AEmojis.Count - 1 do
  begin
    Inc(Result, AMeasureCanvas.TextWidth(AEmojis[I]));
    if I < AEmojis.Count - 1 then
      Inc(Result, cEmojiSpacing);
  end;
end;

procedure DrawPrimaryEmoji(AD2DCanvas: TDirect2DCanvas; const AEmoji: string; const ALeft, ATop: Integer);
begin
  if Trim(AEmoji) = '' then
    Exit;

  AD2DCanvas.Font.Name := 'Segoe UI Emoji';
  AD2DCanvas.Font.Size := cEmojiFontSize;
  AD2DCanvas.Font.Style := [];
  AD2DCanvas.Font.Color := clWindowText;
  AD2DCanvas.TextOut(ALeft, ATop, AEmoji);
end;

procedure DrawSecondaryEmojiRow(AD2DCanvas: TDirect2DCanvas; AMeasureCanvas: TCanvas;
  AEmojis: TStrings; const AWidth, ARight, ATop: Integer);
var
  I: Integer;
  CurrentLeft: Integer;
begin
  if AEmojis.Count <= 1 then
    Exit;

  AMeasureCanvas.Font.Name := 'Segoe UI Emoji';
  AMeasureCanvas.Font.Size := cSecondaryEmojiFontSize;
  AMeasureCanvas.Font.Style := [];

  AD2DCanvas.Font.Name := 'Segoe UI Emoji';
  AD2DCanvas.Font.Size := cSecondaryEmojiFontSize;
  AD2DCanvas.Font.Style := [];
  AD2DCanvas.Font.Color := clWindowText;

  CurrentLeft := ARight - AWidth;
  for I := 1 to AEmojis.Count - 1 do
  begin
    AD2DCanvas.TextOut(CurrentLeft, ATop, AEmojis[I]);
    Inc(CurrentLeft, AMeasureCanvas.TextWidth(AEmojis[I]) + cEmojiSpacing);
  end;
end;

procedure DrawTextLines(AD2DCanvas: TDirect2DCanvas; const ALines: TStrings; const ALeft: Integer;
  var ATop: Integer; const ALineHeight: Integer);
var
  I: Integer;
begin
  for I := 0 to ALines.Count - 1 do
  begin
    AD2DCanvas.TextOut(ALeft, ATop, ALines[I]);
    Inc(ATop, ALineHeight);
  end;
end;

{ TMessagePanel }

constructor TMessagePanel.Create(AOwner: TComponent; AData: TMessageData);
begin
  inherited Create(AOwner);
  FData := AData;
  FAttachmentRect := Rect(0, 0, 0, 0);
  FMeasureBitmap := TBitmap.Create;
  FTitleLines := TStringList.Create;
  FAttachmentLines := TStringList.Create;
  FMessageLines := TStringList.Create;
  FEmojis := TStringList.Create;
  Height := cMinPanelHeight;
  Align := alNone;
end;

destructor TMessagePanel.Destroy;
begin
  FEmojis.Free;
  FMessageLines.Free;
  FAttachmentLines.Free;
  FTitleLines.Free;
  FMeasureBitmap.Free;
  inherited;
end;

procedure TMessagePanel.Resize;
begin
  inherited;
  if Parent <> nil then
    UpdateLayout;
end;

procedure TMessagePanel.MouseMove(Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  UpdateCursor(X, Y);
end;

procedure TMessagePanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
var
  SaveDialog: TSaveDialog;
begin
  inherited;
  if (Button <> mbLeft) or not IsOverAttachment(X, Y) then
    Exit;

  SaveDialog := TSaveDialog.Create(Self);
  try
    SaveDialog.Title := 'Save attachment';
    SaveDialog.FileName := SuggestedAttachmentFileName(FData);
    SaveDialog.Options := SaveDialog.Options + [ofOverwritePrompt, ofPathMustExist];
    if SaveDialog.Execute then
    begin
      Screen.Cursor := crHourGlass;
      try
        DownloadAttachmentToFile(FData.AttachmentURL, SaveDialog.FileName);
      finally
        Screen.Cursor := crDefault;
      end;
    end;
  finally
    SaveDialog.Free;
  end;
end;

procedure TMessagePanel.CMMouseLeave(var Message: TMessage);
begin
  inherited;
  Cursor := crDefault;
end;

procedure TMessagePanel.RecalculateLayout;
begin
  UpdateLayout;
end;

procedure TMessagePanel.UpdateCachedText;
var
  TitleText: string;
  AttachmentText: string;
begin
  BuildEmojiParts(FData.Tag, FEmojis);
  FIconWidth := PrimaryEmojiColumnWidth(FMeasureBitmap.Canvas, FEmojis);
  FSecondaryWidth := SecondaryEmojiRowWidth(FMeasureBitmap.Canvas, FEmojis);
  FTextLeft := cPanelPadding + FIconWidth;
  FTextWidth := Max(150, ClientWidth - FTextLeft - cPanelPadding - FSecondaryWidth -
    IfThen(FSecondaryWidth > 0, cEmojiSpacing, 0));

  TitleText := Trim(FData.Title);
  if TitleText = '' then
    TitleText := '(no title)';
  AttachmentText := AttachmentSummary(FData);

  FMeasureBitmap.Canvas.Font.Name := 'Segoe UI';
  FMeasureBitmap.Canvas.Font.Size := cTitleFontSize;
  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  BuildWrappedLines(FMeasureBitmap.Canvas, TitleText, FTextWidth, FTitleLines);

  FAttachmentLines.Clear;
  if AttachmentText <> '' then
  begin
    FMeasureBitmap.Canvas.Font.Size := cAttachmentFontSize;
    FMeasureBitmap.Canvas.Font.Style := [];
    BuildWrappedLines(FMeasureBitmap.Canvas, AttachmentText, FTextWidth, FAttachmentLines);
  end;

  FMessageLines.Clear;
  if Trim(FData.MessageContent) <> '' then
  begin
    FMeasureBitmap.Canvas.Font.Size := cMessageFontSize;
    FMeasureBitmap.Canvas.Font.Style := [];
    BuildWrappedLines(FMeasureBitmap.Canvas, FData.MessageContent, FTextWidth, FMessageLines);
  end;
end;

procedure TMessagePanel.UpdateLayout;
var
  TotalHeight: Integer;
begin
  if (Parent = nil) or (ClientWidth <= 0) then
    Exit;

  UpdateCachedText;

  FMeasureBitmap.Canvas.Font.Name := 'Segoe UI';
  TotalHeight := cPanelPadding;

  FMeasureBitmap.Canvas.Font.Size := cTitleFontSize;
  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  Inc(TotalHeight, Max(1, FTitleLines.Count) * TextLineHeight(FMeasureBitmap.Canvas));
  Inc(TotalHeight, cTextSpacing);

  FMeasureBitmap.Canvas.Font.Size := cMetaFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  Inc(TotalHeight, TextLineHeight(FMeasureBitmap.Canvas));
  Inc(TotalHeight, cTextSpacing);

  if PriorityText(FData.Priority) <> '' then
  begin
    Inc(TotalHeight, TextLineHeight(FMeasureBitmap.Canvas));
    Inc(TotalHeight, cTextSpacing);
  end;

  if FAttachmentLines.Count > 0 then
  begin
    FMeasureBitmap.Canvas.Font.Size := cAttachmentFontSize;
    Inc(TotalHeight, Max(1, FAttachmentLines.Count) * TextLineHeight(FMeasureBitmap.Canvas));
    Inc(TotalHeight, cTextSpacing);
  end;

  if FMessageLines.Count > 0 then
  begin
    FMeasureBitmap.Canvas.Font.Size := cMessageFontSize;
    Inc(TotalHeight, Max(1, FMessageLines.Count) * TextLineHeight(FMeasureBitmap.Canvas));
    Inc(TotalHeight, cTextSpacing);
  end;

  Height := Max(cMinPanelHeight, TotalHeight + cPanelPadding + cBottomDividerPadding);
end;

procedure TMessagePanel.DrawBackground(AD2DCanvas: TDirect2DCanvas);
begin
  AD2DCanvas.Brush.Color := clWindow;
  AD2DCanvas.FillRect(ClientRect);

  AD2DCanvas.Pen.Color := RGB(225, 225, 225);
  AD2DCanvas.MoveTo(0, Height - 1);
  AD2DCanvas.LineTo(Width, Height - 1);
end;

procedure TMessagePanel.DrawEmojis(AD2DCanvas: TDirect2DCanvas);
begin
  if FEmojis.Count > 0 then
    DrawPrimaryEmoji(AD2DCanvas, FEmojis[0], cPanelPadding, cPanelPadding - 1);
  DrawSecondaryEmojiRow(AD2DCanvas, FMeasureBitmap.Canvas, FEmojis, FSecondaryWidth,
    Width - cPanelPadding, cPanelPadding + 1);
end;

procedure TMessagePanel.DrawTitle(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
var
  LineHeight: Integer;
begin
  AD2DCanvas.Font.Name := 'Segoe UI';
  FMeasureBitmap.Canvas.Font.Size := cTitleFontSize;
  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  AD2DCanvas.Font.Size := cTitleFontSize;
  AD2DCanvas.Font.Style := [fsBold];
  AD2DCanvas.Font.Color := clWindowText;
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  DrawTextLines(AD2DCanvas, FTitleLines, FTextLeft, ATop, LineHeight);
  Inc(ATop, cTextSpacing);
end;

procedure TMessagePanel.DrawTimestamp(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
begin
  FMeasureBitmap.Canvas.Font.Size := cMetaFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  AD2DCanvas.Font.Size := cMetaFontSize;
  AD2DCanvas.Font.Style := [];
  AD2DCanvas.Font.Color := clGrayText;
  AD2DCanvas.TextOut(FTextLeft, ATop, FormatDateTime('yyyy-mm-dd hh:nn:ss', FData.Timestamp));
  Inc(ATop, TextLineHeight(FMeasureBitmap.Canvas) + cTextSpacing);
end;

procedure TMessagePanel.DrawPriority(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
var
  PriorityLine: string;
begin
  PriorityLine := PriorityText(FData.Priority);
  if PriorityLine = '' then
    Exit;

  FMeasureBitmap.Canvas.Font.Size := cMetaFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  AD2DCanvas.Font.Size := cMetaFontSize;
  AD2DCanvas.Font.Style := [];
  AD2DCanvas.Font.Color := PriorityColor(FData.Priority);
  AD2DCanvas.TextOut(FTextLeft, ATop, PriorityLine);
  Inc(ATop, TextLineHeight(FMeasureBitmap.Canvas) + cTextSpacing);
end;

procedure TMessagePanel.DrawAttachment(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
begin
  if FAttachmentLines.Count = 0 then
    Exit;

  FMeasureBitmap.Canvas.Font.Size := cAttachmentFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  FAttachmentRect := Rect(
    FTextLeft,
    ATop,
    FTextLeft + FTextWidth,
    ATop + (FAttachmentLines.Count * TextLineHeight(FMeasureBitmap.Canvas))
  );

  AD2DCanvas.Font.Size := cAttachmentFontSize;
  AD2DCanvas.Font.Style := [fsUnderline];
  AD2DCanvas.Font.Color := clNavy;
  DrawTextLines(AD2DCanvas, FAttachmentLines, FTextLeft, ATop, TextLineHeight(FMeasureBitmap.Canvas));
  AD2DCanvas.Font.Style := [];
  Inc(ATop, cTextSpacing);
end;

procedure TMessagePanel.DrawMessage(AD2DCanvas: TDirect2DCanvas; var ATop: Integer);
begin
  if FMessageLines.Count = 0 then
    Exit;

  FMeasureBitmap.Canvas.Font.Size := cMessageFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  AD2DCanvas.Font.Size := cMessageFontSize;
  AD2DCanvas.Font.Style := [];
  AD2DCanvas.Font.Color := clWindowText;
  DrawTextLines(AD2DCanvas, FMessageLines, FTextLeft, ATop, TextLineHeight(FMeasureBitmap.Canvas));
end;

procedure TMessagePanel.Paint;
var
  D2DCanvas: TDirect2DCanvas;
  CurrentTop: Integer;
begin
  inherited;

  FAttachmentRect := Rect(0, 0, 0, 0);
  D2DCanvas := TDirect2DCanvas.Create(Canvas.Handle, ClientRect);
  try
    D2DCanvas.BeginDraw;
    try
      DrawBackground(D2DCanvas);
      DrawEmojis(D2DCanvas);

      CurrentTop := cPanelPadding;
      DrawTitle(D2DCanvas, CurrentTop);
      DrawTimestamp(D2DCanvas, CurrentTop);
      DrawPriority(D2DCanvas, CurrentTop);
      DrawAttachment(D2DCanvas, CurrentTop);
      DrawMessage(D2DCanvas, CurrentTop);
    finally
      D2DCanvas.EndDraw;
    end;
  finally
    D2DCanvas.Free;
  end;
end;

{ TMessageDisplay }

constructor TMessageDisplay.Create(AOwner: TComponent);
begin
  FMessages := TMessagesList.Create(AOwner);

  FScrollBox := TScrollBox.Create(AOwner);
  FScrollBox.Parent := TWinControl(AOwner);
  FScrollBox.Align := alClient;
  FScrollBox.VertScrollBar.Tracking := True;
  FScrollBox.OnResize := ScrollBoxResize;
end;

constructor TMessageDisplay.Create(AOwner: TComponent; AScrollBox: TScrollBox);
begin
  FMessages := TMessagesList.Create(AOwner);
  FScrollBox := AScrollBox;
  if FScrollBox <> nil then
    FScrollBox.OnResize := ScrollBoxResize;
end;

procedure TMessageDisplay.SetScrollBox(AScrollBox: TScrollBox);
begin
  FScrollBox := AScrollBox;
  if FScrollBox <> nil then
    FScrollBox.OnResize := ScrollBoxResize;
  RebuildPanels;
end;

destructor TMessageDisplay.Destroy;
begin
  FMessages.Free;
  inherited;
end;

procedure TMessageDisplay.ClearBrowser;
var
  I: Integer;
begin
  FMessages.Clear;

  if FScrollBox = nil then
    Exit;

  for I := FScrollBox.ControlCount - 1 downto 0 do
    FScrollBox.Controls[I].Free;
end;

procedure TMessageDisplay.AddMessage(const aData: TMessageData);
begin
  FMessages.Add(aData);
  RebuildPanels;
  if FScrollBox <> nil then
  begin
    FScrollBox.VertScrollBar.Position := 0;
    FScrollBox.Perform(WM_VSCROLL, SB_TOP, 0);
  end;
end;

procedure TMessageDisplay.ScrollBoxResize(Sender: TObject);
begin
  RebuildPanels;
end;

procedure TMessageDisplay.RebuildPanels;
var
  I: Integer;
  Panel: TMessagePanel;
  CurrentTop: Integer;
  ContentWidth: Integer;
begin
  if (FScrollBox = nil) or FRebuildingPanels then
    Exit;

  FRebuildingPanels := True;
  FScrollBox.DisableAlign;
  try
    for I := FScrollBox.ControlCount - 1 downto 0 do
      FScrollBox.Controls[I].Free;

    CurrentTop := cPanelMargin;
    ContentWidth := Max(150, FScrollBox.ClientWidth - (cPanelMargin * 2));

    for I := 0 to FMessages.Count - 1 do
    begin
      Panel := TMessagePanel.Create(FScrollBox, FMessages[I]);
      Panel.Parent := FScrollBox;
      Panel.SetBounds(cPanelMargin, CurrentTop, ContentWidth, Panel.Height);
      Panel.RecalculateLayout;
      Panel.SetBounds(cPanelMargin, CurrentTop, ContentWidth, Panel.Height);
      Inc(CurrentTop, Panel.Height + cTextSpacing);
    end;
  finally
    FScrollBox.EnableAlign;
    FRebuildingPanels := False;
  end;

  FScrollBox.VertScrollBar.Range := CurrentTop + cPanelMargin;
  FScrollBox.Realign;
  for I := 0 to FScrollBox.ControlCount - 1 do
    if FScrollBox.Controls[I] is TMessagePanel then
      TMessagePanel(FScrollBox.Controls[I]).UpdateLayout;
  FScrollBox.Realign;
  for I := 0 to FScrollBox.ControlCount - 1 do
    FScrollBox.Controls[I].Invalidate;
end;

function TMessageDisplay.GetScrollBox: TScrollBox;
begin
  Result := FScrollBox;
end;

end.

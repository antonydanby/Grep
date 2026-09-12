unit MatchesDisplay_FMX;

interface

uses
  Winapi.Windows,
  Winapi.ShellAPI,
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Types,
  System.UITypes,
  System.IOUtils,
  System.Generics.Collections,
  FMX.Types,
  FMX.Controls,
  FMX.DialogService,
  FMX.Graphics,
  FMX.StdCtrls,
  FMX.Objects,
  FMX.ListView,
  FMX.ListView.Types,
  FMX.ListView.Appearances,
  MatchesList;

type
  TMatchesData = MatchesList.TMatchesData;

  TMatchesDisplay = class
  private
    FListView: TListView;
    FDetailsPanel: TRectangle;
    FDetailsPaintBox: TPaintBox;
    FMatches: TMatchesList;
    FSelectedMatch: TMatchesData;
    FExpanded: Boolean;
    FFileIcon: TBitmap;
    FWrappedAbove: TStringList;
    FWrappedMatch: TStringList;
    FWrappedBelow: TStringList;
    procedure ConfigureListView;
    procedure ListViewItemClick(const Sender: TObject; const AItem: TListViewItem);
    procedure DetailsPaint(Sender: TObject; Canvas: TCanvas);
    procedure DetailsClick(Sender: TObject);
    procedure HideDetails;
    procedure UpdateDetails;
    procedure BuildWrappedDetails(ACanvas: TCanvas);
    function CalculateDetailHeight(ACanvas: TCanvas): Single;
    procedure DrawTextLine(ACanvas: TCanvas; const ARect: TRectF; const AText: string;
      const AColor: TAlphaColor; const ASize: Single; const ABold: Boolean);
  public
    constructor Create(AOwner: TComponent; AListView: TListView; ADetailsPanel: TRectangle;
      ADetailsPaintBox: TPaintBox; AFileIcon: TBitmap);
    destructor Destroy; override;
    procedure ClearBrowser;
    procedure AddMatch(const AData: TMatchesData);
    procedure AddMatches(const AData: TObjectList<TMatchesData>);
    function Count: Integer;
    procedure OpenSelectedMatch;
    property Matches: TMatchesList read FMatches;
  end;

implementation

const
  cDetailsPadding = 14;
  cCollapsedHeight = 112;
  cMinListHeight = 120;

function NormalizePreviewText(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #13, ' ', [rfReplaceAll]);
  Result := StringReplace(Result, #10, ' ', [rfReplaceAll]);
  Result := Trim(Result);
end;

procedure AddWrappedParagraph(ACanvas: TCanvas; ALines: TStrings; const AParagraph: string;
  const AMaxWidth: Single);
var
  Remaining: string;
  BreakPos: Integer;
  LastSpace: Integer;
  Prefix: string;
  Low: Integer;
  High: Integer;
  Mid: Integer;
  Best: Integer;
begin
  if AParagraph = '' then
  begin
    ALines.Add('');
    Exit;
  end;

  Remaining := AParagraph;
  while Remaining <> '' do
  begin
    if (AMaxWidth <= 0) or (ACanvas.TextWidth(Remaining) <= AMaxWidth) then
    begin
      ALines.Add(Remaining);
      Exit;
    end;

    Low := 1;
    High := Length(Remaining);
    Best := 1;
    while Low <= High do
    begin
      Mid := (Low + High) div 2;
      Prefix := Copy(Remaining, 1, Mid);
      if ACanvas.TextWidth(Prefix) <= AMaxWidth then
      begin
        Best := Mid;
        Low := Mid + 1;
      end
      else
        High := Mid - 1;
    end;

    BreakPos := Best;
    LastSpace := BreakPos;
    while (LastSpace > 1) and (Remaining[LastSpace] <> ' ') do
      Dec(LastSpace);

    if LastSpace > 1 then
      BreakPos := LastSpace;

    ALines.Add(Copy(Remaining, 1, BreakPos));
    Delete(Remaining, 1, BreakPos);
  end;
end;

procedure BuildWrappedLines(ACanvas: TCanvas; ASourceLines, ADestination: TStrings;
  const AMaxWidth: Single);
var
  I: Integer;
begin
  ADestination.Clear;
  for I := 0 to ASourceLines.Count - 1 do
    AddWrappedParagraph(ACanvas, ADestination, ASourceLines[I], AMaxWidth);
end;

{ TMatchesDisplay }

constructor TMatchesDisplay.Create(AOwner: TComponent; AListView: TListView; ADetailsPanel: TRectangle;
  ADetailsPaintBox: TPaintBox; AFileIcon: TBitmap);
begin
  inherited Create;
  FMatches := TMatchesList.Create(AOwner);
  FListView := AListView;
  FDetailsPanel := ADetailsPanel;
  FDetailsPaintBox := ADetailsPaintBox;
  FSelectedMatch := nil;
  FExpanded := False;
  FFileIcon := AFileIcon;
  FWrappedAbove := TStringList.Create;
  FWrappedMatch := TStringList.Create;
  FWrappedBelow := TStringList.Create;

  ConfigureListView;

  if (FDetailsPanel <> nil) and (FDetailsPaintBox <> nil) then
  begin
    FDetailsPaintBox.OnPaint := DetailsPaint;
    FDetailsPaintBox.OnClick := DetailsClick;
    FDetailsPanel.OnClick := DetailsClick;
    HideDetails;
  end;
end;

destructor TMatchesDisplay.Destroy;
begin
  FWrappedBelow.Free;
  FWrappedMatch.Free;
  FWrappedAbove.Free;
  FMatches.Free;
  inherited;
end;

procedure TMatchesDisplay.ConfigureListView;
begin
  if FListView = nil then
    Exit;

  FListView.ItemAppearance.ItemAppearance := TAppearanceNames.ImageListItemBottomDetail;
  FListView.OnItemClick := ListViewItemClick;
end;

procedure TMatchesDisplay.ClearBrowser;
begin
  FMatches.Clear;
  FSelectedMatch := nil;
  FExpanded := False;

  if FListView <> nil then
  begin
    FListView.Items.BeginUpdate;
    try
      FListView.Items.Clear;
    finally
      FListView.Items.EndUpdate;
    end;
  end;

  HideDetails;
end;

procedure TMatchesDisplay.AddMatch(const AData: TMatchesData);
var
  Item: TListViewItem;
  Preview: string;
begin
  if AData = nil then
    Exit;

  FMatches.Add(AData);

  if FListView = nil then
    Exit;

  Preview := NormalizePreviewText(AData.MatchValue);
  if Length(Preview) > 160 then
    Preview := Copy(Preview, 1, 160) + '...';

  Item := FListView.Items.Add;
  Item.Text := System.IOUtils.TPath.GetFileName(AData.Filename);
  if Item.Text = '' then
    Item.Text := AData.Filename;
  Item.Detail := Format('Line %d - %s', [AData.LineNumber, Preview]);
  Item.Height := 58;
  Item.TagObject := AData;
  if FFileIcon <> nil then
    Item.Bitmap := FFileIcon;
end;

procedure TMatchesDisplay.AddMatches(const AData: TObjectList<TMatchesData>);
var
  MatchData: TMatchesData;
begin
  if AData = nil then
    Exit;

  if FListView <> nil then
    FListView.Items.BeginUpdate;
  try
    while AData.Count > 0 do
    begin
      MatchData := AData.Extract(AData[0]);
      AddMatch(MatchData);
    end;
  finally
    if FListView <> nil then
      FListView.Items.EndUpdate;
  end;
end;

function TMatchesDisplay.Count: Integer;
begin
  Result := FMatches.Count;
end;

procedure TMatchesDisplay.OpenSelectedMatch;
var
  OpenResult: HINST;
begin
  if (FSelectedMatch = nil) or not TFile.Exists(FSelectedMatch.Filename) then
  begin
    TDialogService.MessageDialog('The matched file is no longer available.',
      TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
    Exit;
  end;

  OpenResult := ShellExecute(0, 'open', PChar(FSelectedMatch.Filename), nil, nil, SW_SHOWNORMAL);
  if OpenResult <= 32 then
  begin
    OpenResult := ShellExecute(0, 'open', 'notepad.exe', PChar(FSelectedMatch.Filename), nil, SW_SHOWNORMAL);
    if OpenResult <= 32 then
      TDialogService.MessageDialog('Unable to open the matched file.',
        TMsgDlgType.mtError, [TMsgDlgBtn.mbOK], TMsgDlgBtn.mbOK, 0, nil);
  end;
end;

procedure TMatchesDisplay.ListViewItemClick(const Sender: TObject; const AItem: TListViewItem);
begin
  if (AItem = nil) or not (AItem.TagObject is TMatchesData) then
  begin
    HideDetails;
    Exit;
  end;

  FSelectedMatch := TMatchesData(AItem.TagObject);
  FExpanded := True;
  UpdateDetails;
end;

procedure TMatchesDisplay.DetailsClick(Sender: TObject);
begin
  if FSelectedMatch = nil then
    Exit;

  FExpanded := not FExpanded;
  UpdateDetails;
end;

procedure TMatchesDisplay.HideDetails;
begin
  if FDetailsPanel = nil then
    Exit;

  FDetailsPanel.Visible := False;
  FDetailsPanel.Height := 0;
  if FDetailsPaintBox <> nil then
    FDetailsPaintBox.Repaint;
end;

procedure TMatchesDisplay.UpdateDetails;
begin
  if (FSelectedMatch = nil) or (FDetailsPanel = nil) or (FDetailsPaintBox = nil) then
  begin
    HideDetails;
    Exit;
  end;

  FDetailsPanel.Visible := True;
  FDetailsPanel.Height := CalculateDetailHeight(FDetailsPaintBox.Canvas);
  FDetailsPanel.BringToFront;
  FDetailsPaintBox.Repaint;
end;

procedure TMatchesDisplay.BuildWrappedDetails(ACanvas: TCanvas);
var
  MatchLineSource: TStringList;
  MaxWidth: Single;
begin
  FWrappedAbove.Clear;
  FWrappedMatch.Clear;
  FWrappedBelow.Clear;

  if FSelectedMatch = nil then
    Exit;

  MaxWidth := Max(180, FDetailsPaintBox.Width - (cDetailsPadding * 2));
  BuildWrappedLines(ACanvas, FSelectedMatch.LinesAbove, FWrappedAbove, MaxWidth);
  BuildWrappedLines(ACanvas, FSelectedMatch.LinesBelow, FWrappedBelow, MaxWidth);

  MatchLineSource := TStringList.Create;
  try
    MatchLineSource.Add(FSelectedMatch.MatchValue);
    BuildWrappedLines(ACanvas, MatchLineSource, FWrappedMatch, MaxWidth);
  finally
    MatchLineSource.Free;
  end;
end;

function TMatchesDisplay.CalculateDetailHeight(ACanvas: TCanvas): Single;
var
  LineHeight: Single;
  LineCount: Integer;
  MaxAvailableHeight: Single;
  ParentControl: TControl;
begin
  BuildWrappedDetails(ACanvas);

  ACanvas.Font.Size := 13;
  LineHeight := Max(20, ACanvas.TextHeight('Wg') + 4);

  LineCount := Max(1, FWrappedMatch.Count) + 3;
  if FExpanded then
    Inc(LineCount, FWrappedAbove.Count + FWrappedBelow.Count);

  Result := (LineCount * LineHeight) + (cDetailsPadding * 2);
  if not FExpanded then
    Result := Max(cCollapsedHeight, Result)
  else
  begin
    if (FDetailsPanel.Parent <> nil) and (FDetailsPanel.Parent is TControl) then
    begin
      ParentControl := TControl(FDetailsPanel.Parent);
      MaxAvailableHeight := Max(cCollapsedHeight,
        ParentControl.Size.Height - cMinListHeight - FDetailsPanel.Margins.Bottom);
    end
    else
      MaxAvailableHeight := Result;

    Result := Min(MaxAvailableHeight, Max(cCollapsedHeight, Result));
  end;
end;

procedure TMatchesDisplay.DrawTextLine(ACanvas: TCanvas; const ARect: TRectF; const AText: string;
  const AColor: TAlphaColor; const ASize: Single; const ABold: Boolean);
begin
  ACanvas.Fill.Kind := TBrushKind.Solid;
  ACanvas.Fill.Color := AColor;
  ACanvas.Font.Size := ASize;
  if ABold then
    ACanvas.Font.Style := [TFontStyle.fsBold]
  else
    ACanvas.Font.Style := [];

  ACanvas.FillText(ARect, AText, False, 1, [], TTextAlign.Leading, TTextAlign.Leading);
end;

procedure TMatchesDisplay.DetailsPaint(Sender: TObject; Canvas: TCanvas);
var
  TopPos: Single;
  LineHeight: Single;
  I: Integer;
  TitleText: string;
  LineRect: TRectF;
  HighlightRect: TRectF;
begin
  if FSelectedMatch = nil then
    Exit;

  BuildWrappedDetails(Canvas);
  LineHeight := Max(20, Canvas.TextHeight('Wg') + 4);
  TopPos := cDetailsPadding;

  TitleText := Format('%s (Line %d)', [FSelectedMatch.Filename, FSelectedMatch.LineNumber]);
  LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding, TopPos + LineHeight);
  DrawTextLine(Canvas, LineRect, TitleText, $FF20324D, 15, True);
  TopPos := TopPos + LineHeight + 4;

  if FExpanded then
  begin
    for I := 0 to FWrappedAbove.Count - 1 do
    begin
      LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding, TopPos + LineHeight);
      DrawTextLine(Canvas, LineRect, FWrappedAbove[I], $FF6B7280, 13, False);
      TopPos := TopPos + LineHeight;
    end;
  end;

  HighlightRect := RectF(cDetailsPadding - 4, TopPos - 2, FDetailsPaintBox.Width - cDetailsPadding + 4,
    TopPos + (Max(1, FWrappedMatch.Count) * LineHeight) + 2);
  Canvas.Fill.Kind := TBrushKind.Solid;
  Canvas.Fill.Color := $FFEAF4FF;
  Canvas.FillRect(HighlightRect, 8, 8, [], 1);

  for I := 0 to FWrappedMatch.Count - 1 do
  begin
    LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding, TopPos + LineHeight);
    DrawTextLine(Canvas, LineRect, FWrappedMatch[I], $FF174B87, 13, True);
    TopPos := TopPos + LineHeight;
  end;

  TopPos := TopPos + 6;
  if FExpanded then
  begin
    for I := 0 to FWrappedBelow.Count - 1 do
    begin
      LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding, TopPos + LineHeight);
      DrawTextLine(Canvas, LineRect, FWrappedBelow[I], $FF6B7280, 13, False);
      TopPos := TopPos + LineHeight;
    end;
  end
  else
  begin
    LineRect := RectF(cDetailsPadding, TopPos, FDetailsPaintBox.Width - cDetailsPadding, TopPos + LineHeight);
    DrawTextLine(Canvas, LineRect, 'Click to show surrounding lines', $FF5F6F82, 12, False);
  end;
end;

end.

unit MatchesList;

interface

uses
  System.SysUtils, System.Classes,
  System.Generics.Collections, System.Generics.Defaults;

type
  TMatchesData = class
  public
    MatchID: Int64;
    Filename: string;
    FileTimestamp: TDateTime;
    LineNumber: Integer;
    MatchValue: string;
    LinesAbove: TStringList;
    LinesBelow: TStringList;
    Expanded: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

  TFileMatches = class
  private
    FFilename: string;
    FMatches: TList<TMatchesData>;
    function GetCount: Integer;
    function GetMatch(const AIndex: Integer): TMatchesData;
  public
    constructor Create(const AFilename: string);
    destructor Destroy; override;
    procedure Add(const AMatch: TMatchesData);
    property Filename: string read FFilename;
    property Count: Integer read GetCount;
    property Matches[const AIndex: Integer]: TMatchesData read GetMatch; default;
  end;

  TMatchesList = class
  private
    fList: TObjectList<TMatchesData>;
    fItemIndex: Integer;
    fNextSequence: Int64;
    function GetCurrentItem: TMatchesData;
    function GetItem(const aIndex: Integer): TMatchesData;
    function GetItemIndex: Integer;
    procedure SetItemIndex(const Value: Integer);
  public
    constructor Create(AOwner: TComponent); overload;
    destructor Destroy; override;

    function Count: Integer;

    procedure Clear;

    procedure Add(aItem: TMatchesData);
    function Delete(aMessageID: Int64): boolean;

    procedure First;
    procedure Last;
    procedure Previous;
    procedure Next;
    function Eof: Boolean;
    function Bof: Boolean;

    function Find(aMatch: TPredicate<TMatchesData>): Integer;
    procedure Sort(const aComparer: IComparer<TMatchesData>); overload;
    function Filter(aMatch: TPredicate<TMatchesData>): TObjectList<TMatchesData>;

    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property Items[const aIndex: Integer]: TMatchesData read GetItem; default;
    property CurrentItem: TMatchesData read GetCurrentItem;
    property List: TObjectList<TMatchesData> read fList;
  end;

implementation

{ TMatchesList }

constructor TFileMatches.Create(const AFilename: string);
begin
  inherited Create;
  FFilename := AFilename;
  FMatches := TList<TMatchesData>.Create;
end;

destructor TFileMatches.Destroy;
begin
  FMatches.Free;
  inherited;
end;

procedure TFileMatches.Add(const AMatch: TMatchesData);
begin
  if AMatch <> nil then
    FMatches.Add(AMatch);
end;

function TFileMatches.GetCount: Integer;
begin
  Result := FMatches.Count;
end;

function TFileMatches.GetMatch(const AIndex: Integer): TMatchesData;
begin
  if (AIndex >= 0) and (AIndex < FMatches.Count) then
    Result := FMatches[AIndex]
  else
    Result := nil;
end;

constructor TMatchesData.Create;
begin
  inherited Create;
  LinesAbove := TStringList.Create;
  LinesBelow := TStringList.Create;
  Expanded := False;
end;

destructor TMatchesData.Destroy;
begin
  LinesBelow.Free;
  LinesAbove.Free;
  inherited;
end;

constructor TMatchesList.Create(AOwner: TComponent);
begin
  inherited Create;
  fList := TObjectList<TMatchesData>.Create(True);
  fItemIndex := -1;
  fNextSequence := 0;
end;

destructor TMatchesList.Destroy;
begin
  fList.Free;
  inherited;
end;

procedure TMatchesList.Clear;
begin
  fList.Clear;
  fItemIndex := -1;
  fNextSequence := 0;
end;

function TMatchesList.Count: Integer;
begin
  Result := fList.Count;
end;

procedure TMatchesList.Add(aItem: TMatchesData);
begin
  if aItem = nil then
    Exit;

  Inc(fNextSequence);
  aItem.MatchID := fNextSequence;
  fList.Add(aItem);
  fItemIndex := fList.Count - 1;
end;

function TMatchesList.Delete(aMessageID: Int64): boolean;
var
  i: integer;
  found: boolean;
begin
  i := 0;
  found := false;
  while (not found) and (i < fList.Count) do
  begin
    found := (fList.items[i].MatchID = aMessageID);
    if not found then Inc(i);
  end;
  if found then
  begin
    fList.Delete(i);
    if fList.Count = 0 then
      fItemIndex := -1
    else if fItemIndex >= fList.Count then
      fItemIndex := fList.Count - 1;
  end;
  Result := found;
end;

// --- Filter, Find and Sort functions -----------------------------------------
function TMatchesList.Filter(aMatch: TPredicate<TMatchesData>): TObjectList<TMatchesData>;
var
  item: TMatchesData;
begin
  Result := TObjectList<TMatchesData>.Create(False);
  if not Assigned(aMatch) then Exit;
  for item in fList do
  begin
    if aMatch(item) then Result.Add(item);
  end;
end;

function TMatchesList.Find(aMatch: TPredicate<TMatchesData>): Integer;
var
  i: integer;
begin
  Result := -1;
  if not Assigned(aMatch) then Exit;
  for i := 0 to fList.Count - 1 do
  begin
    if AMatch(fList[i]) then
    begin
      fItemIndex := i;
      Exit(I);
    end;
  end;
end;

procedure TMatchesList.Sort(const aComparer: IComparer<TMatchesData>);
begin
  if not Assigned(AComparer) then Exit;
  fList.Sort(AComparer);
  if Count > 0 then fItemIndex := 0 else fItemIndex := -1;
end;


// --- Dataset like navigation -------------------------------------------------
function TMatchesList.Bof: Boolean;
begin
  Result := (fItemIndex <= 0);
end;

function TMatchesList.Eof: Boolean;
begin
  Result := (fItemIndex >= Count - 1) or (Count = 0);
end;

procedure TMatchesList.First;
begin
  if Count > 0 then fItemIndex := 0;
end;

procedure TMatchesList.Last;
begin
  if Count > 0 then fItemIndex := Count - 1;
end;

procedure TMatchesList.Next;
begin
  if fItemIndex < Count - 1 then Inc(fItemIndex);
end;

procedure TMatchesList.Previous;
begin
  if fItemIndex > 0 then Dec(fItemIndex);
end;


// --- Accessor methods --------------------------------------------------------
function TMatchesList.GetCurrentItem: TMatchesData;
begin
  if (fItemIndex >= 0) and (fItemIndex < Count) then
    Result := fList[fItemIndex]
  else
    Result := nil;
end;

function TMatchesList.GetItem(const aIndex: Integer): TMatchesData;
begin
  if (aIndex >= 0) and (aIndex < Count) then
    Result := fList[aIndex]
  else
    Result := nil;
end;

function TMatchesList.GetItemIndex: Integer;
begin
  Result := fItemIndex;
end;

procedure TMatchesList.SetItemIndex(const Value: Integer);
begin
  if (Value >= -1) and (Value < Count) then fItemIndex := Value;
end;


end.

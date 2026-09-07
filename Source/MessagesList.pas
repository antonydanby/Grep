unit MessagesList;

interface

uses
  System.SysUtils, System.Classes,
  System.Generics.Collections, System.Generics.Defaults;

type
  TMessageData = class
  public
    Title: string;
    Tag: string;
    MessageID: string;
    MessageContent: string;
    Timestamp: TDateTime;
    Sequence: Int64;
    Priority: Integer;
    AttachmentName: string;
    AttachmentURL: string;
    AttachmentSize: Int64;
  end;

  TMessagesList = class
  private
    fList: TObjectList<TMessageData>;
    fItemIndex: Integer;
    fNextSequence: Int64;
    function GetCurrentItem: TMessageData;
    function GetItem(const aIndex: Integer): TMessageData;
    function GetItemIndex: Integer;
    procedure SetItemIndex(const Value: Integer);
  public
    constructor Create(AOwner: TComponent); overload;
    destructor Destroy; override;

    function Count: Integer;

    procedure Clear;

    procedure Add(aItem: TMessageData);
    function Delete(aMessageID: string): boolean;

    procedure First;
    procedure Last;
    procedure Previous;
    procedure Next;
    function Eof: Boolean;
    function Bof: Boolean;

    function Find(aMatch: TPredicate<TMessageData>): Integer;
    procedure Sort(const aComparer: IComparer<TMessageData>); overload;
    function Filter(aMatch: TPredicate<TMessageData>): TObjectList<TMessageData>;

    property ItemIndex: Integer read GetItemIndex write SetItemIndex;
    property Items[const aIndex: Integer]: TMessageData read GetItem; default;
    property CurrentItem: TMessageData read GetCurrentItem;
    property List: TObjectList<TMessageData> read fList;
  end;

implementation

{ TMessagesList }

constructor TMessagesList.Create(AOwner: TComponent);
begin
  inherited Create;
  fList := TObjectList<TMessageData>.Create(True);
  fItemIndex := -1;
  fNextSequence := 0;
end;

destructor TMessagesList.Destroy;
begin
  fList.Free;
  inherited;
end;

procedure TMessagesList.Clear;
begin
  fList.Clear;
  fItemIndex := -1;
  fNextSequence := 0;
end;

function TMessagesList.Count: Integer;
begin
  Result := fList.Count;
end;

procedure TMessagesList.Add(aItem: TMessageData);
begin
  if aItem = nil then
    Exit;

  Inc(fNextSequence);
  aItem.Sequence := fNextSequence;
  fList.Insert(0, aItem);
  fItemIndex := 0;
end;

function TMessagesList.Delete(aMessageID: string): boolean;
var
  i: integer;
  found: boolean;
begin
  i := 0;
  found := false;
  while (not found) and (i < fList.Count) do
  begin
    found := (fList.items[i].MessageID = aMessageID);
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
function TMessagesList.Filter(aMatch: TPredicate<TMessageData>): TObjectList<TMessageData>;
var
  item: TMessageData;
begin
  Result := TObjectList<TMessageData>.Create(False);
  if not Assigned(aMatch) then Exit;
  for item in fList do
  begin
    if aMatch(item) then Result.Add(item);
  end;
end;

function TMessagesList.Find(aMatch: TPredicate<TMessageData>): Integer;
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

procedure TMessagesList.Sort(const aComparer: IComparer<TMessageData>);
begin
  if not Assigned(AComparer) then Exit;
  fList.Sort(AComparer);
  if Count > 0 then fItemIndex := 0 else fItemIndex := -1;
end;


// --- Dataset like navigation -------------------------------------------------
function TMessagesList.Bof: Boolean;
begin
  Result := (fItemIndex <= 0);
end;

function TMessagesList.Eof: Boolean;
begin
  Result := (fItemIndex >= Count - 1) or (Count = 0);
end;

procedure TMessagesList.First;
begin
  if Count > 0 then fItemIndex := 0;
end;

procedure TMessagesList.Last;
begin
  if Count > 0 then fItemIndex := Count - 1;
end;

procedure TMessagesList.Next;
begin
  if fItemIndex < Count - 1 then Inc(fItemIndex);
end;

procedure TMessagesList.Previous;
begin
  if fItemIndex > 0 then Dec(fItemIndex);
end;


// --- Accessor methods --------------------------------------------------------
function TMessagesList.GetCurrentItem: TMessageData;
begin
  if (fItemIndex >= 0) and (fItemIndex < Count) then
    Result := fList[fItemIndex]
  else
    Result := nil;
end;

function TMessagesList.GetItem(const aIndex: Integer): TMessageData;
begin
  if (aIndex >= 0) and (aIndex < Count) then
    Result := fList[aIndex]
  else
    Result := nil;
end;

function TMessagesList.GetItemIndex: Integer;
begin
  Result := fItemIndex;
end;

procedure TMessagesList.SetItemIndex(const Value: Integer);
begin
  if (Value >= -1) and (Value < Count) then fItemIndex := Value;
end;


end.

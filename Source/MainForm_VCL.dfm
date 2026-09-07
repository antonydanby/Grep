object MainForm: TMainForm
  Left = 0
  Top = 0
  Caption = 'Grep'
  ClientHeight = 761
  ClientWidth = 884
  Color = clWhite
  Constraints.MinHeight = 800
  Constraints.MinWidth = 900
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object HeaderPanel: TPanel
    Left = 0
    Top = 0
    Width = 884
    Height = 70
    Align = alTop
    BevelOuter = bvNone
    Color = 9919532
    ParentBackground = False
    TabOrder = 0
    DesignSize = (
      884
      70)
    object TitleLabel: TLabel
      Left = 24
      Top = 6
      Width = 95
      Height = 25
      Caption = 'Quick Grep'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -19
      Font.Name = 'Segoe UI Semibold'
      Font.Style = []
      ParentFont = False
    end
    object SubtitleLabel: TLabel
      Left = 24
      Top = 36
      Width = 380
      Height = 15
      Caption = 
        'Search with text or regex, preview match context, and optionally' +
        ' replace.'
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWhite
      Font.Height = -12
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
    end
    object btnSearch: TButton
      Left = 636
      Top = 22
      Width = 110
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Search'
      TabOrder = 0
      OnClick = btnSearchClick
    end
    object btnClear: TButton
      Left = 752
      Top = 22
      Width = 110
      Height = 28
      Anchors = [akTop, akRight]
      Caption = 'Clear'
      TabOrder = 1
      OnClick = btnClearClick
    end
  end
  object BodyPanel: TPanel
    Left = 0
    Top = 70
    Width = 884
    Height = 691
    Align = alClient
    BevelOuter = bvNone
    Color = 16053485
    ParentBackground = False
    TabOrder = 1
    object FiltersPanel: TPanel
      Left = 0
      Top = 0
      Width = 370
      Height = 691
      Align = alLeft
      BevelOuter = bvNone
      Color = 16053485
      ParentBackground = False
      TabOrder = 0
      object FiltersScrollBox: TScrollBox
        Left = 16
        Top = 16
        Width = 350
        Height = 659
        VertScrollBar.Tracking = True
        Align = alCustom
        Anchors = [akLeft, akTop, akRight, akBottom]
        BorderStyle = bsNone
        Color = 16053485
        ParentColor = False
        TabOrder = 0
        object SearchCard: TPanel
          Left = 0
          Top = 0
          Width = 350
          Height = 337
          Align = alTop
          BevelOuter = bvNone
          Color = clWhite
          ParentBackground = False
          TabOrder = 0
          object SearchCardTitle: TLabel
            Left = 14
            Top = 12
            Width = 46
            Height = 20
            Caption = 'Search'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 4737096
            Font.Height = -15
            Font.Name = 'Segoe UI Semibold'
            Font.Style = []
            ParentFont = False
          end
          object SearchCardDivider: TShape
            Left = 14
            Top = 40
            Width = 304
            Height = 1
            Brush.Color = 15263976
            Pen.Color = 15263976
          end
          object lblFolder: TLabel
            Left = 14
            Top = 56
            Width = 33
            Height = 15
            Caption = 'Folder'
          end
          object lblFind: TLabel
            Left = 14
            Top = 105
            Width = 23
            Height = 15
            Caption = 'Find'
          end
          object lblReplace: TLabel
            Left = 14
            Top = 154
            Width = 67
            Height = 15
            Caption = 'Replace with'
          end
          object lblWildcards: TLabel
            Left = 14
            Top = 203
            Width = 101
            Height = 15
            Caption = 'Filename wildcards'
          end
          object lblContextLines: TLabel
            Left = 194
            Top = 203
            Width = 68
            Height = 15
            Caption = 'Context lines'
          end
          object lblRegex: TLabel
            Left = 14
            Top = 261
            Width = 50
            Height = 15
            Caption = 'Use regex'
          end
          object lblCaseSensitive: TLabel
            Left = 14
            Top = 287
            Width = 73
            Height = 15
            Caption = 'Case sensitive'
          end
          object lblReplaceMode: TLabel
            Left = 14
            Top = 313
            Width = 75
            Height = 15
            Caption = 'Replace mode'
          end
          object edtFolder: TEdit
            Left = 14
            Top = 74
            Width = 244
            Height = 23
            TabOrder = 0
          end
          object btnBrowse: TButton
            Left = 264
            Top = 73
            Width = 54
            Height = 25
            Caption = '...'
            TabOrder = 1
            OnClick = btnBrowseClick
          end
          object edtSearchText: TEdit
            Left = 14
            Top = 123
            Width = 304
            Height = 23
            TabOrder = 2
          end
          object edtReplaceText: TEdit
            Left = 14
            Top = 172
            Width = 304
            Height = 23
            TabOrder = 3
          end
          object edtWildcards: TEdit
            Left = 14
            Top = 221
            Width = 150
            Height = 23
            TabOrder = 4
            Text = '*.*'
          end
          object spnContextLines: TSpinEdit
            Left = 194
            Top = 221
            Width = 124
            Height = 24
            MaxValue = 20
            MinValue = 0
            TabOrder = 5
            Value = 3
          end
          object swRegex: TToggleSwitch
            Left = 246
            Top = 258
            Width = 73
            Height = 20
            TabOrder = 6
            OnClick = ToggleModeChanged
          end
          object swCaseSensitive: TToggleSwitch
            Left = 246
            Top = 284
            Width = 73
            Height = 20
            TabOrder = 7
            OnClick = ToggleModeChanged
          end
          object swReplaceMode: TToggleSwitch
            Left = 246
            Top = 310
            Width = 73
            Height = 20
            TabOrder = 8
            OnClick = ToggleModeChanged
          end
        end
        object FiltersCard: TPanel
          Left = 0
          Top = 347
          Width = 350
          Height = 312
          Align = alBottom
          BevelOuter = bvNone
          Color = clWhite
          ParentBackground = False
          TabOrder = 1
          object FiltersCardTitle: TLabel
            Left = 14
            Top = 12
            Width = 41
            Height = 20
            Caption = 'Filters'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 4737096
            Font.Height = -15
            Font.Name = 'Segoe UI Semibold'
            Font.Style = []
            ParentFont = False
          end
          object FiltersCardDivider: TShape
            Left = 14
            Top = 40
            Width = 304
            Height = 1
            Brush.Color = 15263976
            Pen.Color = 15263976
          end
          object lblIncludeSubfolders: TLabel
            Left = 14
            Top = 56
            Width = 97
            Height = 15
            Caption = 'Include subfolders'
          end
          object lblIncludeHidden: TLabel
            Left = 14
            Top = 82
            Width = 103
            Height = 15
            Caption = 'Include hidden files'
          end
          object lblIncludeBinary: TLabel
            Left = 14
            Top = 108
            Width = 99
            Height = 15
            Caption = 'Include binary files'
          end
          object lblUseDateFrom: TLabel
            Left = 14
            Top = 142
            Width = 125
            Height = 15
            Caption = 'Use modified from date'
          end
          object lblUseDateTo: TLabel
            Left = 14
            Top = 199
            Width = 110
            Height = 15
            Caption = 'Use modified to date'
          end
          object lblMinSize: TLabel
            Left = 14
            Top = 256
            Width = 101
            Height = 15
            Caption = 'Min file size (bytes)'
          end
          object lblMaxSize: TLabel
            Left = 174
            Top = 256
            Width = 102
            Height = 15
            Caption = 'Max file size (bytes)'
          end
          object swIncludeSubfolders: TToggleSwitch
            Left = 246
            Top = 53
            Width = 73
            Height = 20
            State = tssOn
            TabOrder = 0
          end
          object swIncludeHidden: TToggleSwitch
            Left = 246
            Top = 79
            Width = 73
            Height = 20
            TabOrder = 1
          end
          object swIncludeBinary: TToggleSwitch
            Left = 246
            Top = 105
            Width = 73
            Height = 20
            TabOrder = 2
          end
          object swUseDateFrom: TToggleSwitch
            Left = 246
            Top = 139
            Width = 73
            Height = 20
            TabOrder = 3
            OnClick = ToggleModeChanged
          end
          object dtpDateFrom: TDateTimePicker
            Left = 14
            Top = 164
            Width = 304
            Height = 23
            Date = 46255.000000000000000000
            Time = 46255.000000000000000000
            TabOrder = 4
          end
          object swUseDateTo: TToggleSwitch
            Left = 246
            Top = 196
            Width = 73
            Height = 20
            TabOrder = 5
            OnClick = ToggleModeChanged
          end
          object dtpDateTo: TDateTimePicker
            Left = 14
            Top = 221
            Width = 304
            Height = 23
            Date = 46255.000000000000000000
            Time = 46255.000000000000000000
            TabOrder = 6
          end
          object edtMinSize: TEdit
            Left = 14
            Top = 274
            Width = 144
            Height = 23
            TabOrder = 7
          end
          object edtMaxSize: TEdit
            Left = 174
            Top = 274
            Width = 144
            Height = 23
            TabOrder = 8
          end
        end
        object Panel1: TPanel
          Left = 0
          Top = 337
          Width = 350
          Height = 10
          Align = alClient
          BevelOuter = bvNone
          Color = clWhite
          Constraints.MinHeight = 4
          ParentBackground = False
          TabOrder = 2
        end
      end
    end
    object ResultsPanel: TPanel
      Left = 370
      Top = 0
      Width = 514
      Height = 691
      Align = alClient
      BevelOuter = bvNone
      Color = 16053485
      ParentBackground = False
      TabOrder = 1
      DesignSize = (
        514
        691)
      object MatchesPanel: TPanel
        Left = 6
        Top = 16
        Width = 490
        Height = 657
        Anchors = [akLeft, akTop, akRight, akBottom]
        BevelOuter = bvNone
        BorderWidth = 4
        Color = clWhite
        ParentBackground = False
        TabOrder = 0
        object TogglePanel: TPanel
          Left = 4
          Top = 653
          Width = 482
          Height = 0
          Align = alBottom
          BevelOuter = bvNone
          Color = clWhite
          ParentBackground = False
          TabOrder = 0
          Visible = False
          OnClick = TogglePanelClick
        end
        object MatchesListView: TListView
          Left = 4
          Top = 60
          Width = 482
          Height = 593
          Align = alClient
          Columns = <
            item
              Caption = 'File'
              Width = 350
            end
            item
              Caption = 'Line'
              Width = 70
            end
            item
              Caption = 'Match'
              Width = 300
            end>
          ColumnClick = False
          ReadOnly = True
          RowSelect = True
          TabOrder = 1
          ViewStyle = vsReport
          OnSelectItem = MatchesListViewSelectItem
        end
        object ResultsHeaderPanel: TPanel
          Left = 4
          Top = 4
          Width = 482
          Height = 56
          Align = alTop
          BevelOuter = bvNone
          Color = clWhite
          ParentBackground = False
          TabOrder = 2
          object ResultsTitleLabel: TLabel
            Left = 18
            Top = 12
            Width = 69
            Height = 20
            Caption = 'Results (0)'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = 4737096
            Font.Height = -15
            Font.Name = 'Segoe UI Semibold'
            Font.Style = []
            ParentFont = False
          end
          object ResultsStatusLabel: TLabel
            Left = 18
            Top = 32
            Width = 32
            Height = 15
            Caption = 'Ready'
            Font.Charset = DEFAULT_CHARSET
            Font.Color = clGrayText
            Font.Height = -12
            Font.Name = 'Segoe UI'
            Font.Style = []
            ParentFont = False
          end
        end
      end
    end
  end
end

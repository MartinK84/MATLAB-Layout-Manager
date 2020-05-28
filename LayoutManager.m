classdef LayoutManager
    
    methods (Static)
        function [FileName] = GetSettingsFile()
            localSettings = fullfile(pwd, 'layoutManager.json');
            globalSettings = fullfile(userpath, 'layoutManager.json');            
            
            if (exist(localSettings, 'file') == 2)
                FileName = localSettings;
            else
                FileName = globalSettings;
            end
        end
        
        function [Layout] = GetDefaultLayout()
            % default figure layout
            Layout.figure.Color = [1 1 1];
            
            % default axes layout
            Layout.axis.FontSize = 20;
            Layout.axis.XAxis.LineWidth = 2;
            Layout.axis.YAxis.LineWidth = 2;
            Layout.axis.ZAxis.LineWidth = 2;
            Layout.axis.XGrid = 'on';
            Layout.axis.YGrid = 'on';
            Layout.axis.ZGrid = 'on';
            Layout.axis.XMinorGrid = 'on';
            Layout.axis.YMinorGrid = 'on';
            Layout.axis.ZMinorGrid = 'on';
            
            % default line layout
            Layout.line.LineWidth = 2;
        end
        
        function DemoLayout(Name)
            if (nargin < 1)
                Name = [];
            end
            
            % demo plot
            fig = figure;
            x = linspace(0,2*pi,1000);
            y = sin(x);
            plot(x,y);
            xlim([x(1), x(end)]);
            if (isempty(Name))
                printName = 'Default';
            else
                printName = Name;
            end
            title(sprintf('Layout: %s', printName));
            
            % apply layout
            LayoutManager.ApplyLayout(Name, fig);
        end
        
        function ApplyLayout(Name, Figure)
            if (nargin < 1)
                Name = [];
            end
            if (nargin < 2)
                Figure = gcf;
            end
            assert(~isempty(Figure.CurrentAxes), 'Figure has no axis');            
            
            % get layouts 
            layoutList = LayoutManager.LoadLayouts();
            layoutIndex = LayoutManager.GetLayoutIndex(layoutList, Name);
            if (isempty(layoutIndex))
                if (~isempty(Name))
                    warning('Layout %s not found, using default', Name);
                end
                layout = LayoutManager.GetDefaultLayout();
            else
                layout = layoutList{layoutIndex};
            end            
            
            % copy layout properties           
            Figure.Units = 'Normalized';
            LayoutManager.CopyProperties(layout.figure, Figure);            
            
            axesHandles = find(contains(arrayfun(@class, Figure.Children, 'UniformOutput', false),'.Axes') == 1);
            for iAxes = 1:length(axesHandles)
                curAxis = Figure.Children(axesHandles(iAxes));
                LayoutManager.CopyProperties(layout.axis,curAxis);    
                
                lineHandes = find(contains(arrayfun(@class, curAxis.Children, 'UniformOutput', false),'.Line') == 1);
                for iLine = 1:length(lineHandes)
                    LayoutManager.CopyProperties(layout.line, curAxis.Children(lineHandes(iLine)));    
                end
            end                        
        end
        
        function [Layouts] = LoadLayouts()
            try
                % open file and read all text
                fid = fopen(LayoutManager.GetSettingsFile(), 'r');
                paramsStr = fread(fid, inf, 'uint8');
                paramsStr = char(paramsStr); %#ok<FREAD>
    
                % close file handle
                fclose(fid);
                
                % decode json
                Layouts = jsondecode(LayoutManager.MakeRow(paramsStr));
                if (~iscell(Layouts)) && (~isempty(Layouts))
                    layoutsArray = Layouts;
                    Layouts = [];                    
                    for iLayout = 1:length(layoutsArray) 
                        Layouts{iLayout} = layoutsArray(iLayout); 
                    end                    
                end                
            catch
                Layouts = [];
            end
        end
        
        function Save(Name, Figure, Params)
            if (nargin < 3)
                Params = 'Basic';
            end
            if (nargin < 2)
                Figure = gcf;
            end
            assert(~isempty(Figure.CurrentAxes), 'Figure has no axis');
            Axis = Figure.CurrentAxes(1);
            
            % create layout to save
            layout = [];
            layout.Name = Name;
            
            % figure properties that we want to store
            layout.figure.Color = Figure.Color;
            if (contains(lower(Params), 'full'))
                layout.figure.ToolBar = Figure.ToolBar;
                layout.figure.MenuBar = Figure.MenuBar;
                layout.figure.WindowState = Figure.WindowState;
                layout.figure.WindowStyle = Figure.WindowStyle;
                Figure.Units = 'Normalized'; % save position as normalized units
                layout.figure.Position = Figure.Position;
            end
            
            % axis properties
            layout.axis.FontSize = Axis.FontSize;
            layout.axis.XAxis.LineWidth = Axis.XAxis.LineWidth;
            layout.axis.YAxis.LineWidth = Axis.YAxis.LineWidth;
            layout.axis.ZAxis.LineWidth = Axis.ZAxis.LineWidth;
            layout.axis.XGrid = Axis.XGrid;
            layout.axis.YGrid = Axis.YGrid;
            layout.axis.ZGrid = Axis.ZGrid;
            layout.axis.XMinorGrid = Axis.XMinorGrid;
            layout.axis.YMinorGrid = Axis.YMinorGrid;
            layout.axis.ZMinorGrid = Axis.ZMinorGrid;
            
            % line properties
            if (contains(lower(Params), 'line'))
                lineHandles = find(contains(arrayfun(@class, Axis.Children, 'UniformOutput', false),'.Line') == 1);
                if (~isempty(lineHandles))
                    line = Axis.Children(lineHandles(1));
                    
                    layout.line.LineWidth = line.LineWidth;
                    if (contains(lower(Params), 'full'))
                        layout.line.LineStyle = line.LineStyle;
                        layout.line.Marker = line.Marker;
                        layout.line.MarkerSize = line.MarkerSize;
                        layout.line.MarkerFaceColor = line.MarkerFaceColor;
                        layout.line.MarkerEdgeColor = line.MarkerEdgeColor;
                    end
                end
            end
            
            % get layouts and update or add based on layout name
            layoutList = LayoutManager.LoadLayouts();
            layoutIndex = LayoutManager.GetLayoutIndex(layoutList, layout.Name);
            if (isempty(layoutIndex))
                layoutList = cat(2, makeRow(layoutList), {layout});
            else
                layoutList{layoutIndex} = layout;
            end
            
            try
                % convert to JSON
                paramsStr = jsonencode(layoutList);
                paramsStr = strrep(paramsStr, ',"', sprintf(',%s"',newline)); % add newlines for better readability
                paramsStr = strrep(paramsStr, '{', sprintf('{%s',newline)); 
                paramsStr = strrep(paramsStr, '}', sprintf('%s}',newline)); 
    
                % save to text file
                fid = fopen(LayoutManager.GetSettingsFile(), 'w');
                fwrite(fid, paramsStr);
                fclose(fid);
            catch
                 fprintf(1,'There was error when saving the layout:\n');
                 fprintf(1,'The identifier was:\n%s',e.identifier);
                 fprintf(1,'There was an error! The message was:\n%s',e.message);
            end
        end
        
        function [Index] = GetLayoutIndex(LayoutList, Name)
            Index = [];
            if isempty(LayoutList)
                return;
            end
            
            for iLayout = 1:length(LayoutList)
                if (strcmpi(LayoutList{iLayout}.Name, Name))
                    Index = iLayout;
                    break;
                end
            end
        end
        
        function List()
            fprintf('\n<strong>List of stored layouts:</strong>\n');
            
            layoutList = LayoutManager.LoadLayouts();
            for iLayout = 1:length(layoutList)
                layout = layoutList{iLayout};
                fprintf('\t%s\n', layout.Name);
            end
            
            fprintf('\n');
        end
    end
    
    methods (Static, Hidden)
        
        function Dst = MakeRow(Src)
            if iscolumn(Src)
                Dst = Src.';
            else
                Dst = Src;
            end
        end
        
        function CopyProperties(Src, Dst, Prefix)
            try
                if (nargin < 3)
                    Prefix = [];
                end

                if (isempty(Prefix))
                    fields = fieldnames(Src);
                else
                    fields = fieldnames(getfield(Src, Prefix{:}));
                end

                for iField = 1:length(fields)      
                    subPrefix = cat(1, Prefix, {fields{iField}});
                    field = getfield(Src, subPrefix{:});

                    if (isstruct(field))
                        LayoutManager.CopyProperties(Src, Dst, subPrefix);
                        continue;
                    end                
    
                    % only update if changed (to avoid not necessary calling
                    % of figure/axis/drawing callback functions)
                    changed = true;
                    try
                        changed = ~isequal(getfield(Dst, subPrefix{:}), field);
                        changed = changed && ~isequal(getfield(Dst, subPrefix{:}), field.');
                    catch
                    end
                    if (changed)
                        %fprintf('%s - %s - %s\n', subPrefix{:}, getfield(Dst, subPrefix{:}), field);
                        Dst = setfield(Dst, subPrefix{:}, field);
                    end
                end
            catch
            end
        end        
    end
end
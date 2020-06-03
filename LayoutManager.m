classdef LayoutManager
% A static Helper class for managing (saving and restoring) figure, axes 
% and plot layouts.
%
% With this small MATLAB Layout Manager you can easily save the layout of
% any figure and restore it to any other figure. The layouts are
% persistently stored between sessions so that you can easily create 
% templates for your preferred figure designs and apply them to other
% figures with a single line of code.
%
% For a mode detailed description and a demo please see the <a href="matlab:edit('README.md')">README.md</a>
%
% Example:
%   [... Plotting code ...]
%   LayoutManager.Save('Demo'); % save the curennt figure layout and design
%   [... Plotting another figure ...]
%   LayoutManager.ApplyLayout('Demo'); % restore the previously saved layout
    
    methods (Static)
        
        function [FileName] = GetSettingsFile()
            % function [FileName] = GetSettingsFile()
            %
            % Get the path to the settings file used for storing the layouts.
            % The function will first check if the layoutManager.json file
            % exists in the current working directora. If not the
            % layoutManager.json file will be returned from the MATLAB
            % userpath directory.
            %
            % Typically this function is only used internally
            %
            % Returns:
            %   FileName:   path to the layoutManager.json file
            %
            % Example:
            %   path = LayoutManager.GetSettingsFile();

            localSettings = fullfile(pwd, 'layoutManager.json');
            globalSettings = fullfile(userpath, 'layoutManager.json');            
            
            if (exist(localSettings, 'file') == 2)
                FileName = localSettings;
            else
                FileName = globalSettings;
            end
        end
        
        function [Layout] = GetDefaultLayout()
            % function [Layout] = GetDefaultLayout()
            %
            % Returns the default layout struct that is used when no
            % settings file exists
            %
            % Returns:
            %   Layout:  struct containing the default layout settings
            %
            % This function is typically only used internally
            %
            % Example:
            %   layout = LayoutManager.GetDefaultLayout();
            
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
            % function DemoLayout(Name)
            %
            % Creates a demo plot and applies the given layout. This
            % function can be used to test layouts. If no layout is given
            % the default layout will be used
            %
            % Parmaeters:
            %   Name:   name of the layout which is to be applied to the
            %           demo figure
            %
            % Example:
            %   LayoutManager.DemoLayout('Demo');

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
            % function ApplyLayout(Name, Figure)
            % 
            % Load the layout with the given Name and apply all of its
            % layout properties to the given figure.
            %
            % Parameters:
            %   Name:               name of the layout to load and apply
            %   Figure (optional):  figure handle. If not set uses 'gcf'
            %
            % Example:
            %   LayoutManager.ApplyLayout('Demo');
            %   LayoutManager.ApplyLayout('Demo', gcf);
            
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
            if (isfield(layout,'figure'))
                LayoutManager.CopyProperties(layout.figure, Figure);
            end
            
            axesHandles = find(contains(arrayfun(@class, Figure.Children, 'UniformOutput', false),'.Axes') == 1);
            for iAxes = 1:length(axesHandles)
                curAxis = Figure.Children(axesHandles(iAxes));
                if (isfield(layout,'axis'))
                    LayoutManager.CopyProperties(layout.axis,curAxis);    
                end
                
                if (isfield(layout,'line'))
                    lineHandes = find(contains(arrayfun(@class, curAxis.Children, 'UniformOutput', false),'.Line') == 1);
                    for iLine = 1:length(lineHandes)
                        LayoutManager.CopyProperties(layout.line, curAxis.Children(lineHandes(iLine)));    
                    end
                end
            end                        
        end
        
        function [Layouts] = LoadLayouts()
            % function [Layouts] = LoadLayouts()
            %
            % Load all layouts from the settings file and return them as
            % array of layout structs. 
            %
            % Returns:
            %   Layouts:    array of layout structs
            %  
            % Examples:
            %   layouts = LayoutManager.LoadLayouts();
            
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
            % function Save(Name, Figure, Params)
            %
            % Save the layout of the given Figure under the specified Name.
            % Optionially sepcify which layout parameters are to be
            % saved using the Params option. 
            %
            % Options for Params are:
            %   'Basic' or empty:   default settings
            %   'Full':             store also figure location, toolbar,
            %                       menubar and window state
            %   'Line':             store LineStyle, LineWidth and Marker
            %                       settings. The settings will be taken
            %                       from the first line graph of the first
            %                       figure axis
            % A combination of parameter such as 'Full,Line' is also
            % possible. 
            %
            % Parameters:
            %   Name:                name of the saved layout (existing 
            %                        layouts with the same name will be overwritten)
            %   Figure (optional):   handle to the figure of which the
            %                        layout will be saved. Uses 'gcf' if
            %                        not set.
            %   Params (optional):   sepcify which layout parameters to
            %                        save (see above for details)
            %
            % Example:
            %   LayoutManager.Save('Demo');
            %   LayoutManager.Save('Demo', gcf, 'Line);
            
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
                layoutList = cat(2, LayoutManager.MakeRow(layoutList), {layout});
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
            % [Index] = GetLayoutIndex(LayoutList, Name)
            %
            % From a given LayoutList return the index of the layout with
            % the given Name.
            % 
            % Parameters:
            %   LayoutList: array of layout structs
            %   Name:       name of the layout to find
            %
            % Arguments:
            %   layoutList = LayoutManaget.LoadLayouts();
            %   [index] = LayoutManager.GetLayoutIndex(layoutList, 'Demo');
            
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
            % function List()
            % 
            % Lists all available layouts
            % 
            % Example:
            %   LayoutManager.List();
            
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
        % internally used functions
        
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
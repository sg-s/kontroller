% part of Kontroller
function [data] = ImageAnnotator(datafile)

data =[];
ControlParadigm = [];



% load it 
if ischar(datafile)
    temp=load(datafile);
    data = temp.data;
    ControlParadigm = temp.ControlParadigm;
    clear temp;
end

% declare the globals
ParadigmHandles = [];
ThisParadigm =[];
ThisImage = [];
ImageHandles =[];
ImageMenu = [];
ImageAxis = [];
PushButtonHandles = [];
PointHandles =NaN(1,100);

% make the GUI
f1 = figure('Position',[60 60 1050 700],'Toolbar','none','Menubar','none','Name','Image Annotator','NumberTitle','off','Resize','on','HandleVisibility','on');
ImageAxis = subplot(1,1,1); hold on
axis ij
axis off
set(ImageAxis,'OuterPosition',[0 0.2 1 0.8]);
AnnotateMenu = uimenu(f1,'Label','Annotate','Enable','on');
uimenu(AnnotateMenu,'Label','Add New Point...','Callback',@AddNewPoint);

ParadigmMenu = uimenu(f1,'Label','Paradigm','Enable','on');
% programtically generate a menu with items from paradigm names
CPNames = {ControlParadigm.Name};
ParadigmHandles = zeros(1,length(CPNames));
for i = 1:length(CPNames)
    ParadigmHandles(i) = uimenu(ParadigmMenu,'Label',CPNames{i},'Callback',@SetParadigm);
end
clear i

% generate some pushbuttons
c = {'k','g','r','b','m','k','g','r','b','m'}; % colors
PushButtonHandles = NaN(1,8);
for i = 1:8
    l = 10+130*(i-1);
    PushButtonHandles(i) = uicontrol(f1,'Position',[l,120,120,30],'style','pushbutton','String','1','Visible','off','Callback',@MarkPoint);
    
end

Points = 0*(1:length(PushButtonHandles));

% show buttons for points already in data
PointsAlreadyInData = {};
for i = 1:length(data)
    if ~isempty(data(i).webcam)
        temp=fieldnames(data(i).webcam(1));
        temp(ismember(temp,{'pic','m','timestamp'})) = [];
        for k = 1:length(temp)
            if ~ismember(temp{k},PointsAlreadyInData)
                PointsAlreadyInData(end+1) = temp(k);
            end
        end
        clear j
    end

end
clear i

for i = 1:length(PointsAlreadyInData)
    Points(i) = 1;
    set(PushButtonHandles(i),'String',PointsAlreadyInData{i},'Visible','on')

end
clear i



% save button
uicontrol(f1,'Position',[30,30,120,30],'style','pushbutton','String','SAVE','Visible','on','Callback',@SaveCallback);

% next  and previous image button
uicontrol(f1,'Position',[30,430,50,50],'style','pushbutton','String','<','Visible','on','Callback',@PrevCallback);
uicontrol(f1,'Position',[930,430,50,50],'style','pushbutton','String','>','Visible','on','Callback',@NextCallback);


    function [] = SetParadigm(SelectedParadigm,~)
        % figure out how many images are in this paradigm
        ThisParadigm = find(ParadigmHandles == SelectedParadigm);
        try
            nimages=length(data(ThisParadigm).webcam);
        catch
            nimages=  0;
        end
        
        if isempty(ImageMenu)
            ImageMenu = uimenu(f1,'Label','Image #','Enable','on');
        else
            for j = 1:length(ImageHandles)
                delete(ImageHandles(j))
            end
        end
        % programtically generate a menu with items from images
        ImageHandles = [];
        for j = 1:nimages
            ImageHandles(j) = uimenu(ImageMenu,'Label',mat2str(j),'Callback',@SetImage);
        end
        clear j
        
    end

    function  [] = NextCallback(~,~)
        SetImage(ImageHandles(ThisImage+1));
    end

    function  [] = PrevCallback(~,~)
        SetImage(ImageHandles(ThisImage-1));
    end

    function [] = SetImage(SelectedImage,~)
        ThisImage = find(ImageHandles == SelectedImage);
        axis(ImageAxis);
        imagesc(data(ThisParadigm).webcam(ThisImage).pic);
        
        % show already annotated data if any
        if sum(Points)
            % grab the names of the points
            for j = find(Points)
                temp = get(PushButtonHandles(j),'String');
                if iscell(temp)
                    temp = cell2mat(temp);
                end
                if isfield(data(ThisParadigm).webcam(ThisImage),temp)
                    eval(strcat('temp=data(ThisParadigm).webcam(ThisImage).',temp,';'))
                    if ~isempty(temp)
                        scatter(temp(1),temp(2),64,c{j},'filled');
                    end
                end
            end
            
        end
        
    end

    function [] = AddNewPoint(~,~)
        % spawn a UI to grab a new name for the point
        point_name = inputdlg('Enter name for point');
        
        
        show_this= find(Points==0,1,'first');
        
        % unhide a button and label it correctly
        Points(show_this) = 1;
        set(PushButtonHandles(show_this),'Visible','on','String',point_name)
    end

    function [] = MarkPoint(src,~)
        % ask the user to label a point
        [x,y] = ginput(1);
        
        ThisPoint = find(PushButtonHandles == src);
        
        % label the point in the image as such
        temp = get(src,'String');
        if iscell(temp)
            temp = cell2mat(temp);
        end
        eval(strcat('data(ThisParadigm).webcam(ThisImage).',temp,'=[x y];'));
        
        % check if there was a previously marked point
        if ~isnan(PointHandles(ThisPoint))
            delete(PointHandles(ThisPoint))
        end

        % add a marker to clarify things
        PointHandles(ThisPoint)=scatter(x,y,64,c{ThisPoint},'filled');

        


    end

    function [] = SaveCallback(~,~)
        t = msgbox('SAVING...')
        save(datafile,'data','-append');
        delete(t);
        msgbox('SAVED!')
    end


end




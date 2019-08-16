# new plotting functions
library(tidyverse) # dplyr, ggplot
library(grid)
library(gridExtra)
library(scales)
library(stringr)
library(cowplot)
theme_set(theme_grey())
library(imager)

plotCloudFigs <- function(scenario, zz, yrs, var, myTitle, legendTitle, legendWrap = NULL)
{
  # Used to generate cloud figures.  Commented out are colors used for plots in DCP presentations
  # and the median projections from the 07' Interim Guidelines (shown with double hash ##)
  
  zz <- zz %>%
    dplyr::filter(StartMonth %in% scenario, Year %in% yrs, Variable == var) %>%
    # compute the 10/50/90 and aggregate by start month
    dplyr::group_by(StartMonth, Year, Variable) %>%
    dplyr::summarise('Med' = median(Value), 'Min' = quantile(Value,.1), 
                     'Max' = quantile(Value,.9)) 
  
  # Set tick marks for x and y axis
  myXLabs <- seq(1990,3000,5)
  myYLabs <- seq(900,4000,50)
  
  #  Pulling historical Pool Elevation data
  if(var == 'Powell.Pool Elevation'){
    hist <- read.csv('data/HistPowellPE.csv')
    hist$Variable <- 'Powell.Pool Elevation'
    
    # Adding switch to allow plotting of correct IG important elevations
    Switch <- T
    EQLine <- as.data.frame(read.csv('data/EQLine.csv'))
    EQLine$StartMonth <- 'Historical Elevation'
    
    ##IGProj <- read.csv('C:/RCodes/Process-CRSS-Res-TribalWaterStudy/data/IGMedProjections_Powell.csv')
    ##IGProj$Variable <- 'Powell.Pool Elevation'
  }else{
    hist <- read.csv('data/HistMeadPE.csv')  
    hist$Variable <- 'Mead.Pool Elevation'
    
    # Adding switch to allow plotting of correct IG important elevations
    Switch <- F
    
    ##IGProj <- read.csv('C:/RCodes/Process-CRSS-Res-TribalWaterStudy/data/IGMedProjections_Mead.csv')
    ##IGProj$Variable <- 'Mead.Pool Elevation'
  }
  
  # Formatting data frame to match zz
  hist$StartMonth <- 'Historical Elevation'
  hist$Med <- hist$Min <- hist$Max <- hist$EOCYPE
  hist <- within(hist, rm(EOCYPE))
  hist <- hist[c("StartMonth","Year","Variable","Med","Min","Max")]
  
  # Formatting Interim Guidelines data frame to match zz
  ##IGProj$StartMonth <- 'Median Interim Guidelines FEIS'
  ##IGProj$Med <- IGProj$Min <- IGProj$Max <- IGProj$EOCYPE
  ##IGProj <- within(IGProj, rm(EOCYPE))
  ##IGProj <- IGProj[c("StartMonth","Year","Variable","Med","Min","Max")]
  
  # Getting all scenarios passed to fxn
  addIC <- unique(zz$StartMonth)
  
  # Appending last historical year pool elevation for each scenario
  for(i in 1:length(addIC)){
    zz <- bind_rows(zz, hist[length(hist[,1]),])
    zz$StartMonth[length(zz$StartMonth)] <- addIC[i]
  }
  
  # Appending historical data
  zz <- bind_rows(hist,zz)
  ##zz <- bind_rows(zz,IGProj)
  
  # Setting colors for graph- ensures historical data is black on plot
  colorNames <- unique(zz$StartMonth)
  #DCP colors (to match AZ Big Bang slides)"#54FF9F","#F4A460"
  #Grey for Interim Guidelines Projections (if included) #8B8682. Add to end.
  #plotColors <- c("#000000","#F8766D", "#00BFC4") #Conor's reverted colors
  plotColors <- c("#000000", "#00BFC4","#F8766D") #Stress test vs DNF colors  NORMAL CLOUD COLORS
  #plotColors <- c("#000000", "#F8766D") #, "#00BA38", "#619CFF" - multiple comparisons
  names(plotColors) <- colorNames
  
  # Adding factors so ggplot does not alphebetize legend
  zz$StartMonth = factor(zz$StartMonth, levels=colorNames)
  
  # Generating labels for the lines in ggplot
  histLab = "Historical Elevation"
  ##IGLab = "\"2007 Projections\""
  names(histLab) = "Historical Elevation"
  ##names(IGLab) = "\"2007 Projections\""
  histLab = append(histLab, cloudLabs)
  ##histLab = append(histLab, IGLab)
  
  # Read in Reclamation logo png
  im <- load.image('logo/660LT-TK-flush.png')
  im_rast <- grid::rasterGrob(im, interpolate = T)
  
  # Parameters for cloud plot customization (line thicknesses, text size, etc.)
  # Have been pulled out for convenience
  #Text
  TitleSize = 13
  AxisText = 11
  LegendLabText = 9.5
  
  AxisLab = 9
  LabSize = 2.9
  LegendText = 8
  
  #Lines
  IGStartLine = .8
  OpsLines = .6
  Medians = 1
  GridMaj = .25
  GridMin = .25
  
  #Y axis limits
  yaxmin = floor(min(zz$Min)/50)*50
  yaxmax = ceiling(max(zz$Max)/50)*50
  
  #Other
  LegendWidth = 1
  LegendHeight = 2.5
  
  
  # Start making the plot
  gg <- ggplot(zz, aes(x=Year, y=Med, color=StartMonth, group=StartMonth)) +  theme_light()
  
  # Generate plot a to make ribbon legend
  name <- str_wrap("10th to 90th percentile of full range",20)
  gga <- gg + geom_ribbon(data = subset(zz,StartMonth %in% rev(addIC)),aes(ymin=Min, ymax=Max, fill = StartMonth), 
                          alpha = 0.5, linetype = 2, size = 0.5*Medians) +
    scale_fill_manual(name, 
                      values = plotColors, guide = guide_legend(order=1),
                      labels = str_wrap(cloudLabs, 15)) + scale_color_manual(name,
                                                                             values = plotColors, guide = guide_legend(order=1),
                                                                             labels = str_wrap(cloudLabs, 15))  +
    theme(legend.text = element_text(size=LegendText),legend.title = element_text(size=LegendLabText, face="bold"),
          legend.box.margin = margin(0,0,0,0), legend.key = element_rect(), legend.key.size = unit(1.75, 'lines')) 
  legenda <- get_legend(gga)
  
  # Generate plot b to take medians legend
  ggb <- gg + geom_line(size=Medians) + 
    scale_color_manual(name = str_wrap("Historical and Median Projected Pool Elevation",20),
                       values = plotColors, labels = str_wrap(histLab, 15)) +
    theme(legend.text = element_text(size=LegendText),legend.title = element_text(size=LegendLabText, face="bold"),
          legend.box.margin = margin(0,0,0,0), legend.key = element_rect(), legend.key.size = unit(1.75, 'lines')) 
  legendb <- get_legend(ggb)
  
  # Make legend grob.  4 rows used to make legend close together and in the middle with respects to the vertical
  gglegend <- plot_grid(NULL, legenda,legendb, NULL, align = 'hv', nrow=4)
  
  # Generate plot
  gg <- gg + geom_vline(xintercept=2007, size = IGStartLine, color = '#808080') + 
    annotate("text", x=2007.1, y = yaxmin, 
             label = 'Adoption of the 2007\nInterim Guidelines', size = LabSize, hjust = 0,
             fontface = "bold", color = '#303030') + 
             {if(Switch)geom_line(data=EQLine, aes(x = Year, y = EQLine), size = OpsLines,
                                  color = '#808080', linetype = 3)} +  
    geom_vline(xintercept=2019, size = IGStartLine, color = '#808080') +
    annotate("text", x=2019.1, y = yaxmin, label = 'Adoption of the Drought\nContingency Plan', 
             size = LabSize, hjust = 0, fontface = "bold", color = '#303030') +
    #{if(Switch)annotate("text", x=2020.1, y = yaxmin,
    #         label = 'Adoption of the Drought\nResponse Operations', size = LabSize, hjust=0,
    #         fontface = 'bold', color = '#303030')} +
    scale_x_continuous(minor_breaks = 1990:3000, breaks = myXLabs,
                       labels = myXLabs, expand = c(0,0)) +
    scale_y_continuous(minor_breaks = seq(900,4000,25), 
                       breaks = myYLabs, labels = comma, limits = c(yaxmin, yaxmax)) +
    geom_ribbon(data = subset(zz,StartMonth %in% addIC),aes(ymin=Min, ymax=Max, fill = StartMonth), 
                alpha = 0.5, linetype = 2, size = 0.5*Medians) + #, colour = NA) + #Orig alpha =0.3
    geom_line(size=Medians) +
    scale_fill_manual(str_wrap("10th to 90th percentile of full range",20),
                      values = plotColors, guide = FALSE,
                      labels = str_wrap(cloudLabs, 15)) + 
    scale_color_manual(name = str_wrap("Historical and Median Projected Pool Elevation",20),
                       values = plotColors, guide = FALSE,
                       labels = str_wrap(histLab, 15)) +
    labs(y = 'Elevation (feet msl)\n', title = myTitle, x = '') + 
    theme(plot.title = element_text(size = TitleSize),
          ## axis.text.x = element_text(size = AxisLab),
          axis.text.y = element_text (size =AxisLab),
          axis.title = element_text(size=AxisText, face = "plain", color = 'grey30'),
          panel.grid.minor = element_line(size = GridMin),
          panel.grid.major = element_line(size = GridMaj)) +
    guides(fill=FALSE) +
    
    # Adding lines for Mead ops - plot only if Switch = False
    {if(Switch!=TRUE)geom_segment(x=2007, y=1075, xend =2026, yend = 1075, size = OpsLines, 
        color ='#808080', linetype = 3)} + 
    {if(Switch!=TRUE)annotate("text", x = 2007.1, y = 1070, label = "Level 1 Shortage Condition", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +
    {if(Switch!=TRUE)geom_segment(x=2007, y=1050, xend =2026, yend = 1050, size = OpsLines, 
        color ='#808080', linetype = 3)} +
    {if(Switch!=TRUE)annotate("text", x = 2007.1, y = 1045, label = "Level 2 Shortage Condition", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +
    {if(Switch!=TRUE)geom_segment(x=2007, y=1025, xend =2026, yend = 1025, size = OpsLines, 
        color ='#808080', linetype = 3)} +
    {if(Switch!=TRUE)annotate("text", x = 2007.1, y = 1020, label = "Level 3 Shortage Condition", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +
    {if(Switch!=TRUE)geom_segment(x=2007, y=1145, xend =2026, yend = 1145, size = OpsLines, 
        color ='#808080', linetype = 3)} +
    {if(Switch!=TRUE)annotate("text", x = 2007.1, y = 1140, label = "Normal or ICS Surplus Condition", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +
    {if(Switch!=TRUE)annotate("text", x = 2007.1, y = yaxmax, label = "Surplus Condition", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +
    #Adding in lines for DCP mead ops
    #{if(Switch!=TRUE)geom_segment(x=2020, y=1090, xend = 2026, yend = 1090, size = OpsLines,
    #    color = '#808080', linetype = 6)} +
    #{if(Switch!=TRUE)annotate("text", x=2020.1, y=1085, label = 'Level 1 Contribution',
    #    size = LabSize, hjust = 0, color = '#505050')} +
    #{if(Switch!=TRUE)geom_segment(x=2020, y=1045, xend = 2026, yend = 1045, size = OpsLines,
    #    color = '#808080', linetype = 6)} +
    #{if(Switch!=TRUE)annotate("text", x=2020.1, y=1040, label = 'Level 2 Contribution',
    #    size = LabSize, hjust = 0, color = '#505050')} +
    
    # Adding lines and annotation for Powell ops - plot only if Switch = True
    {if(Switch)annotate("text", x = 2007.1, y = yaxmax, label = "Equalization Tier", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +
    ##{if(Switch)geom_segment(x=1998, y=3490, xend =2026, yend = 3490, size = OpsLines, 
    ##   color ='#808080', linetype = 3)} + 
    ##{if(Switch)annotate("text", x = 1999.5, y = 3485, label = "Minimum Power Pool", 
    ##   size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +
    {if(Switch)geom_segment(x=2007, y=3525, xend =2026, yend = 3525, size = OpsLines, 
        color ='#808080', linetype = 3)} + 
    {if(Switch)annotate("text", x = 2007.1, y = 3520, label = "Lower Elevation Balancing Tier", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} +    
    {if(Switch)geom_segment(x=2007, y=3575, xend =2026, yend = 3575, size = OpsLines, 
        color ='#808080', linetype = 3)} + 
    {if(Switch)annotate("text", x = 2007.1, y = 3570, label = "Mid Elevation Release Tier", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} + 
    {if(Switch)annotate("text", x = 2007.1, y = 3582, label = "Upper Elevation Balancing Tier", 
        size = LabSize, hjust = 0, fontface = "italic", color = '#505050')} + 
    #Adding Drought Response Ops
    #{if(Switch)geom_segment(x=2020, y=3525, xend = 2026, yend = 3525, size = OpsLines,
    #    color = '#808080', linetype = 6)} +
    #{if(Switch)annotate("text", x = 2020.1, y = 3518, label = "Drought Response Ops\nTarget Elevation",
    #    size = LabSize, hjust = 0, color = '#505050')} +
    
    # Add BOR Logo
    annotation_custom(im_rast, ymin = yaxmin, ymax = yaxmin + 12, xmin = 1999, xmax = 2006) 
  gg <- plot_grid(gg, gglegend, rel_widths = c(2,.4))
  gg
}

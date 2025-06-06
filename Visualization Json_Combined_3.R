## Purpose of the script:
# To load and install all packages needed to run the application
### Author(s): Sarah Braun
### Date originally Created: 2025-01-08
### Contact Information: sarah.braun@med.uni-greifswald.de
# For more information, please visit: github

################################################################################
# Load required packages
################################################################################
# packages <- c("shiny", "jsonlite", "ggplot2", "leaflet", "shinythemes", "shinyjqui", "geodata")
# install.packages(setdiff(packages, installed.packages()[, "Package"]))

library(shiny)
library(jsonlite)
library(ggplot2)
library(leaflet)
library(shinythemes)
library(shinyjqui)
library(geodata)

################################################################################
# Create User Interface
################################################################################

ui <- fluidPage(
  theme = shinytheme("spacelab"), 
  tags$head(
    # Custom CSS 
    tags$style(HTML("
      .plot_box {
          width: 300px;
          padding: 15px;
          border: 1px solid #B0B0B0;
          border-radius: 8px;
          box-shadow: 0 4px 8px rgba(0, 0, 0, 0.1);
          background-color: transparent;  /* Transparent background for underlying histogram visibility */
          position: absolute;
      }
    ")),
    # JavaScript: Stack ALL plot boxes 
    tags$script(HTML("
      $(document).on('click', '#stackPlots', function() {
        $('.plot_box').css({top: '0px', left: '0px'});
      });
    ")),
    # JavaScript: Stack ONLY the selected two plot boxes 
    tags$script(HTML("
      $(document).on('click', '#stackSelectedPlots', function() {
        var selectedPlots = $('#selectedPlotsToStack').val();
        if (selectedPlots) {
          if(selectedPlots.length > 2) { selectedPlots = selectedPlots.slice(0,2); }
          selectedPlots.forEach(function(plotName) {
             $('.plot_box[data-plot-name=\"' + plotName + '\"]').css({top: '0px', left: '0px'});
          });
        }
      });
    "))
  ),
  navbarPage(
    title = "Medical Data Visualization Dashboard",
    
    tabPanel("JSON Data Upload",
             sidebarLayout(
               sidebarPanel(
                 h4("JSON Data Upload"),
                 fileInput("jsonFiles", "Upload JSON Data", accept = ".json", multiple = TRUE),
                 br(),
                 h4("Data integration centers in Germany"),
                 leafletOutput("map", height = "400px")
               ),
               mainPanel(
                 h4("Guide"),
                 p("This application provides an intuitive interface for uploading JSON files containing medical data. Users can explore and analyze their data through various visualization options – including histograms, pie charts, and line charts. Adjust the chart transparency and freely arrange the plots via drag-and-drop for enhanced comparison and analysis. Additionally, a dedicated Statistics section summarizes the uploaded data with key metrics such as total count and mean values per file."),
                 br(),
                 h4("Uploaded JSON Datasets"),
                 tableOutput("jsonList")
               )
             )
    ),
    
    tabPanel("Visualization",
             fluidRow(
               column(12,
                      # Button to stack all plot boxes
                      actionButton("stackPlots", "Stack All Plots"),
                      br(), br(),
                      # Controls for selective stacking 
                      selectInput("selectedPlotsToStack", "Select two plots to stack:", 
                                  choices = NULL, multiple = TRUE),
                      actionButton("stackSelectedPlots", "Stack Selected Plots"),
                      br(), br(),
                      div(
                        id = "plot_area",
                        style = "position: relative; height: 800px; border: 1px solid #DDD; overflow: hidden;",
                        uiOutput("plotsUI")
                      )
               )
             )
    ),
    
    tabPanel("Combined Data",
             fluidRow(
               # Left column: Plots
               column(
                 width = 8,
                 h4("Combined Data Plot"),
                 plotOutput("combinedPlot"),
                 hr(),
                 h4("Intersection Plot"),
                 plotOutput("intersectionPlot")
               ),
               # Right column: Controls 
               column(
                 width = 4,
                 div(
                   style = "padding: 15px; border: 1px solid #DDD; border-radius: 8px; background-color: #FFF;",
                   h4("Data Controls"),
                   checkboxGroupInput("combineFiles", "Select JSON Files to Combine", choices = NULL),
                   uiOutput("valueSelectors"),
                   actionButton("combineData", "Combine Data"),
                   downloadButton("downloadCombined", "Download Combined Data (JSON)"),
                   br(), br(),
                   h4("Intersection Settings"),
                   p("Only categories present in ALL selected files are considered."),
                   selectInput("intersectionValues", "Common Categories", choices = NULL, multiple = TRUE),
                   actionButton("combineIntersection", "Combine Intersection Data"),
                   downloadButton("downloadIntersection", "Download Intersection Data (JSON)")
                 )
               )
             )
    ),
    
    tabPanel("Statistics",
             fluidRow(
               column(12,
                      h4("Statistics for Uploaded Data"),
                      p("Below is a table with basic statistics for each uploaded file:"),
                      tableOutput("statTable"),
                      hr(),
                      h4("Category Summary"),
                      p("The table below shows each unique category across all uploaded JSON files. The cells are color-coded as follows:"),
                      tags$ul(
                        tags$li(strong("Pastel Green:"), " Category present in ALL files"),
                        tags$li(strong("Pastel Yellow:"), " Category present in at least 2 (but not all) files"),
                        tags$li(strong("Pastel Red:"), " Category present in only 1 file")
                      ),
                      p("The categories are sorted by color – green first, then yellow, then red."),
                      uiOutput("categorySummary")
               )
             )
    )
  )
)

################################################################################
# Create Server
################################################################################

server <- function(input, output, session) {
  
  # Function to load JSON data from a given file path
  loadJsonData <- function(filePath) {
    jsonData <- fromJSON(filePath)
    data.frame(
      Category = jsonData$Histogram$Category$`@value`,
      Count = as.numeric(jsonData$Histogram$Count$`@value`)
    )
  }
  
  # Reactive expression to capture all uploaded JSON files
  allData <- reactive({
    req(input$jsonFiles)
    filePaths <- input$jsonFiles$datapath
    fileNames <- input$jsonFiles$name
    lapply(seq_along(filePaths), function(i) {
      list(
        name = fileNames[i],
        data = loadJsonData(filePaths[i])
      )
    })
  })
  
  # Global maximum count 
  globalMax <- reactive({
    req(allData())
    max(unlist(lapply(allData(), function(file) max(file$data$Count, na.rm = TRUE))))
  })
  
  # Display list of uploaded files
  output$jsonList <- renderTable({
    req(input$jsonFiles)
    data.frame(Files = input$jsonFiles$name)
  })
  
  # Table with basic statistics per file
  output$statTable <- renderTable({
    req(allData())
    fileList <- allData()
    statsList <- lapply(seq_along(fileList), function(i) {
      fileData <- fileList[[i]]
      filteredData <- fileData$data
      list(
        File = fileData$name,
        Count = nrow(filteredData),
        Mean = ifelse(nrow(filteredData) > 0, mean(filteredData$Count, na.rm = TRUE), NA)
      )
    })
    do.call(rbind, statsList)
  })
  
  # Update file selection for Combined Data
  observe({
    req(input$jsonFiles)
    updateCheckboxGroupInput(
      session, "combineFiles", 
      choices = sapply(allData(), function(x) x$name),
      selected = sapply(allData(), function(x) x$name)
    )
  })
  
  # Update selection for selective stacking of plots
  observe({
    req(allData())
    updateSelectInput(session, "selectedPlotsToStack",
                      choices = sapply(allData(), function(x) x$name))
  })
  
  # Create dynamic value selectors 
  observe({
    req(input$combineFiles)
    selectedFiles <- input$combineFiles
    fileList <- allData()
    valueSelectors <- lapply(selectedFiles, function(fileName) {
      fileData <- fileList[[which(sapply(fileList, function(f) f$name == fileName))]]$data
      selectInput(
        paste0("values_", fileName), 
        label = paste("Select values for", fileName), 
        choices = unique(fileData$Category), 
        selected = unique(fileData$Category), 
        multiple = TRUE
      )
    })
    output$valueSelectors <- renderUI({ tagList(valueSelectors) })
  })
  
  # ---------------------------------------------------------------------------
  # 1) Stacked Histogram for Combined Data
  # ---------------------------------------------------------------------------
  
  combinedDataReactive <- reactiveVal(NULL)
  
  observeEvent(input$combineData, {
    req(input$combineFiles)
    selectedFiles <- input$combineFiles
    fileList <- allData()
    combinedData <- do.call(rbind, lapply(selectedFiles, function(fileName) {
      fileData <- fileList[[which(sapply(fileList, function(f) f$name == fileName))]]$data
      selectedCategories <- input[[paste0("values_", fileName)]]
      filteredData <- fileData[fileData$Category %in% selectedCategories, ]
      filteredData$Source <- fileName
      filteredData
    }))
    combinedDataReactive(combinedData)
    
    output$combinedPlot <- renderPlot({
      req(combinedData)
      ggplot(combinedData, aes(x = Category, y = Count, fill = Source)) +
        geom_bar(stat = "identity", position = "stack") +
        labs(title = "Combined Data (Stacked)", x = "Category", y = "Count") +
        scale_fill_brewer(palette = "Set2") +
        theme_minimal(base_size = 14, base_family = "Helvetica")
    })
  })
  
  # Download handler for Combined Data
  output$downloadCombined <- downloadHandler(
    filename = function() { paste("combined_data_", Sys.Date(), ".json", sep = "") },
    content = function(file) {
      cData <- combinedDataReactive()
      if (!is.null(cData)) { write_json(cData, file) }
    }
  )
  
  # ---------------------------------------------------------------------------
  # 2) Intersection (Stacked) Histogram + Download
  # ---------------------------------------------------------------------------
  
  intersectionDataReactive <- reactiveVal(NULL)
  
  observe({
    req(input$combineFiles)
    selectedFiles <- input$combineFiles
    fileList <- allData()
    if (length(selectedFiles) == 0) {
      updateSelectInput(session, "intersectionValues", choices = character(0), selected = character(0))
      return(NULL)
    }
    commonCategories <- Reduce(intersect, lapply(selectedFiles, function(fileName) {
      fileList[[which(sapply(fileList, function(f) f$name == fileName))]]$data$Category
    }))
    updateSelectInput(session, "intersectionValues",
                      choices = commonCategories,
                      selected = commonCategories)
  })
  
  observeEvent(input$combineIntersection, {
    req(input$combineFiles)
    selectedFiles <- input$combineFiles
    fileList <- allData()
    intersectionSelected <- input$intersectionValues
    intersectionData <- do.call(rbind, lapply(selectedFiles, function(fileName) {
      df <- fileList[[which(sapply(fileList, function(f) f$name == fileName))]]$data
      dfFiltered <- df[df$Category %in% intersectionSelected, ]
      dfFiltered$Source <- fileName
      dfFiltered
    }))
    intersectionDataReactive(intersectionData)
    
    output$intersectionPlot <- renderPlot({
      req(intersectionData)
      ggplot(intersectionData, aes(x = Category, y = Count, fill = Source)) +
        geom_bar(stat = "identity", position = "stack") +
        labs(title = "Intersection Data (Stacked)", x = "Category", y = "Count") +
        scale_fill_brewer(palette = "Set2") +
        theme_minimal(base_size = 14, base_family = "Helvetica")
    })
  })
  
  # Download handler for Intersection Data
  output$downloadIntersection <- downloadHandler(
    filename = function() { paste("intersection_data_", Sys.Date(), ".json", sep = "") },
    content = function(file) {
      iData <- intersectionDataReactive()
      if (!is.null(iData)) { write_json(iData, file) }
    }
  )
  
  # ---------------------------------------------------------------------------
  # Map Display
  # ---------------------------------------------------------------------------
  output$map <- renderLeaflet({
    locations <- data.frame(
      name = c("Greifswald", "Dresden", "Leipzig", "Aachen", "Hannover", "Hamburg", "Berlin"),
      lat = c(54.093, 51.050, 51.339, 50.775, 52.374, 53.550, 52.520),
      lng = c(13.387, 13.738, 12.374, 6.083, 9.738, 9.993, 13.405)
    )
    
    germany <- gadm("Germany", level = 0, path = tempdir())  # Load Germany boundaries
    
    leaflet() %>%
      addProviderTiles(providers$CartoDB.PositronNoLabels) %>%
      addPolygons(data = germany, color = "#333333", weight = 1, fill = FALSE) %>%
      setView(lng = 10.5, lat = 51.0, zoom = 6) %>%
      addCircleMarkers(
        data = locations,
        lat = ~lat, lng = ~lng,
        label = ~name,
        radius = 6, color = "steelblue", fill = TRUE, fillOpacity = 0.9
      )
  })
  
  # ---------------------------------------------------------------------------
  # Visualization Tab: Dynamic, draggable plots with unified scaling
  # ---------------------------------------------------------------------------
  output$plotsUI <- renderUI({
    req(allData())
    fileList <- allData()
    tagList(
      lapply(seq_along(fileList), function(i) {
        # Each plot container gets a data attribute "data-plot-name"
        jqui_draggable(
          div(
            id = paste0("plot_box_", i),
            class = "plot_box",
            `data-plot-name` = fileList[[i]]$name,
            div(
              style = "display: flex; justify-content: space-between; align-items: center;",
              h4(fileList[[i]]$name),
              checkboxInput(paste0("checkbox_", i), label = NULL, value = TRUE)
            ),
            selectizeInput(
              inputId = paste0("filter_", i),
              label = "Choose values:",
              choices = unique(fileList[[i]]$data$Category),
              multiple = TRUE
            ),
            selectInput(
              inputId = paste0("plotType_", i),
              label = "Choose Visualization:",
              choices = c("Histogram", "Pie Chart", "Line Chart")
            ),
            uiOutput(paste0("plotUI_", i)),
            sliderInput(paste0("opacity_", i), "Transparency:", 
                        min = 0.1, max = 1, value = 1, step = 0.1)
          )
        )
      })
    )
  })
  
  observe({
    req(allData())
    fileList <- allData()
    lapply(seq_along(fileList), function(i) {
      fileData <- fileList[[i]]
      plotId <- paste0("plot_", i)
      checkboxId <- paste0("checkbox_", i)
      opacityId <- paste0("opacity_", i)
      filterId <- paste0("filter_", i)
      plotTypeId <- paste0("plotType_", i)
      plotUIId <- paste0("plotUI_", i)
      
      output[[plotUIId]] <- renderUI({
        if (input[[checkboxId]]) {
          plotOutput(outputId = plotId, height = "300px")
        } else {
          NULL
        }
      })
      
      output[[plotId]] <- renderPlot({
        req(input[[checkboxId]])
        alpha <- input[[opacityId]]
        selectedCategories <- input[[filterId]]
        # If no selection is made, show full dataset
        if (is.null(selectedCategories) || length(selectedCategories) == 0) {
          filteredData <- fileData$data
        } else {
          filteredData <- fileData$data[fileData$data$Category %in% selectedCategories, ]
        }
        
        p <- ggplot(filteredData, aes(x = Category, y = Count, fill = Category)) +
          geom_bar(stat = "identity", alpha = alpha) +
          labs(title = fileData$name, x = "Category", y = "Count") +
          scale_y_continuous(limits = c(0, globalMax())) +
          scale_fill_brewer(palette = "Set2") +
          theme_minimal(base_size = 14, base_family = "Helvetica")
        
        if (input[[plotTypeId]] == "Pie Chart") {
          p <- ggplot(filteredData, aes(x = "", y = Count, fill = Category)) +
            geom_bar(width = 1, stat = "identity", alpha = alpha) +
            coord_polar("y", start = 0) +
            labs(title = fileData$name) +
            scale_fill_brewer(palette = "Set2") +
            theme_minimal(base_size = 14, base_family = "Helvetica")
        } else if (input[[plotTypeId]] == "Line Chart") {
          p <- ggplot(filteredData, aes(x = Category, y = Count, group = 1)) +
            geom_line(color = "steelblue", size = 1.2) +
            geom_point(color = "steelblue", size = 3) +
            labs(title = fileData$name, x = "Category", y = "Count") +
            scale_y_continuous(limits = c(0, globalMax())) +
            theme_minimal(base_size = 14, base_family = "Helvetica")
        }
        
        p + theme(
          panel.background = element_rect(fill = "transparent", colour = NA),
          plot.background = element_rect(fill = "transparent", colour = NA),
          panel.grid = element_blank()
        )
      }, bg = "transparent")
    })
  })
  
  # ---------------------------------------------------------------------------
  # Unified Statistics Tab: Generate an HTML table with color-coded cells,
  # sorted by color (green, yellow, red)
  # ---------------------------------------------------------------------------
  output$categorySummary <- renderUI({
    req(allData())
    fileList <- allData()
    # Create mapping: For each category
    categoryMap <- list()
    allFileNames <- sapply(fileList, function(f) f$name)
    for (f in fileList) {
      fileName <- f$name
      catVector <- unique(f$data$Category)
      for (catVal in catVector) {
        if (is.null(categoryMap[[catVal]])) {
          categoryMap[[catVal]] <- c(fileName)
        } else {
          categoryMap[[catVal]] <- union(categoryMap[[catVal]], fileName)
        }
      }
    }
    
    nFiles <- length(allFileNames)
    
    # For each category, determine the count and assign a color group:
    # - Present in all files: group 1 (pastel green)
    # - Present in at least 2 (but not all): group 2 (pastel yellow)
    # - Present in only 1: group 3 (pastel red)
    rows <- lapply(names(categoryMap), function(cat) {
      count <- length(categoryMap[[cat]])
      if (count == nFiles) {
        group <- 1
        color <- "#d4edda"  # green
      } else if (count >= 2) {
        group <- 2
        color <- "#fff3cd"  # yellow
      } else {
        group <- 3
        color <- "#f8d7da"  #red
      }
      list(category = cat, count = count, group = group, color = color)
    })
    
    # Sort: first group 1 (green), then group 2 (yellow), then group 3 (red); within groups
    rows_sorted <- rows[order(sapply(rows, function(x) x$group),
                              sapply(rows, function(x) x$category))]
    
    # Generate the HTML table
    html <- "<table style='width:100%; border-collapse: collapse;' border='1'>"
    # Table header
    html <- paste0(html, "<tr style='background-color: #f2f2f2;'><th>Category</th>")
    for (fn in allFileNames) {
      html <- paste0(html, "<th>", fn, "</th>")
    }
    html <- paste0(html, "<th>Files</th></tr>")
    
    # Table rows
    for (row in rows_sorted) {
      html <- paste0(html, "<tr>")
      html <- paste0(html, "<td>", row$category, "</td>")
      for (fn in allFileNames) {
        if (fn %in% categoryMap[[row$category]]) {
          html <- paste0(html, "<td style='background-color:", row$color, "; text-align: center;'>", "", "</td>")
        } else {
          html <- paste0(html, "<td></td>")
        }
      }
      html <- paste0(html, "<td style='text-align: center;'>", row$count, "</td>")
      html <- paste0(html, "</tr>")
    }
    
    html <- paste0(html, "</table>")
    HTML(html)
  })
}

shinyApp(ui = ui, server = server)

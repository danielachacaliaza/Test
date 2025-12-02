// ==================================================
// 0. INITIALIZATION
// ==================================================
run("Close All");
run("Clear Results"); 
print("\\Clear");

// Configuración para que funcione la elongación (AR)
// [cite: 7, 10] PDF: Segmentar, analizar y contar elongados.
run("Set Measurements...", "area centroid shape redirect=None decimal=3");

// ==================================================
// 1. INPUTS
// ==================================================
// [cite: 5] PDF: Ask the user for an Input folder
InputFolder = getDirectory("Select input images folder");

// [cite: 15] PDF: Ask the user for an Output folder
OutputFolder = getDirectory("Select output folder to save images");

Files = getFileList(InputFolder);

// Contadores Globales
// [cite: 13] PDF: Accumulate data to compute averages at the end
numAllNuclei = 0;
numAllCentrosomes = 0;
numAllElongated = 0;
ImageCount = 0;

// ==================================================
// 2. MAIN LOOP
// ==================================================
// [cite: 6] PDF: Write a loop to process the images
for(i=0; i<lengthOf(Files); i++)
{
    // Filtro para asegurar que es una imagen
    if (endsWith(Files[i], ".tif") || endsWith(Files[i], ".jpg") || endsWith(Files[i], ".stk")) {
        
        ImageCount = ImageCount + 1;
        ImagePath = Files[i];
        
        // --- LIMPIEZA OBLIGATORIA ---
        run("Clear Results");
        roiManager("Reset");
        run("Remove Overlay"); 
        
        open(InputFolder + ImagePath);
        rename("Input");
        run("Split Channels");
        
        // NO CERRAMOS C1 (Fase) todavía, la usaremos de fondo para la imagen final [cite: 14]
        
        // ------------------------------------------------
        // A. ANALIZAR NÚCLEOS (C3)
        // ------------------------------------------------
        // [cite: 7] PDF: Properly segment the nuclei to a mask
        selectImage("C3-Input");
        run("Duplicate...", "title=Mask");
        run("Median...", "radius=1");
        run("Subtract Background...", "rolling=10");
        setAutoThreshold("Yen dark 16-bit no-reset");
        setOption("BlackBackground", true);
        run("Convert to Mask");
        run("Watershed");
        
        // [cite: 8] PDF: Analyze the nuclei mask and add the nuclei to the ROI Manager
        run("Analyze Particles...", "display exclude include summarize add measure");
        
        numNuclei = nResults;
        numAllNuclei = numAllNuclei + numNuclei;
        
        // --- COLOREAR Y CLASIFICAR NÚCLEOS ---
        // [cite: 10] PDF: Optionally color them in the ROI Manager
        
        totalArea = 0;
        numElongatedLocal = 0;
        
        for (x=0; x<nResults; x++){
            // Sumar Área [cite: 9]
            valorArea = getResult("Area", x);
            totalArea = totalArea + valorArea;
            
            // Chequear Elongación (AR >= 1.6)
            ar = getResult("AR", x);
            
            roiManager("Select", x);
            if (ar >= 1.6){
                numElongatedLocal = numElongatedLocal + 1;
                // Núcleos Elongados en AZUL (para distinguirlos)
                roiManager("Set Color", "blue"); 
                roiManager("Set Line Width", 2);
            } else {
                // Núcleos Normales en AMARILLO
                roiManager("Set Color", "yellow"); 
                roiManager("Set Line Width", 2);
            }
        }
        roiManager("Deselect");
        numAllElongated = numAllElongated + numElongatedLocal;
        
        // Limpiar máscaras
        close("Mask");
        close("C3-Input");
        
        // ------------------------------------------------
        // B. ANALIZAR CENTROSOMAS (C2)
        // ------------------------------------------------
        // [cite: 10] PDF: Properly detect the centrosomes (Find Maxima output List recommended for counting)
        selectImage("C2-Input");
        
        // Usamos output=Count para el dato numérico limpio
        run("Find Maxima...", "prominence=180 output=Count");
        
        // Recuperar el dato de la tabla
        numCentrosomes = getResult("Count", nResults-1); 
        numAllCentrosomes = numAllCentrosomes + numCentrosomes;
        
        // ------------------------------------------------
        // C. REPORTAR DATOS (LOG)
        // ------------------------------------------------
        // [cite: 12] PDF: Print the results for this image in the Log window
        print("\n--- Image " + ImageCount + ": " + ImagePath + " ---");
        print("Nuclei: " + numNuclei);
        
        if (numNuclei > 0){
            avgArea = totalArea / numNuclei;
            print("Avg Nuclei Area: " + avgArea);
            
            pctElongated = (numElongatedLocal / numNuclei) * 100;
            print("Elongated Nuclei: " + numElongatedLocal + " (" + pctElongated + "%)");
            
            avgCentrosomes = numCentrosomes / numNuclei;
            print("Avg Centrosomes/Nuclei: " + avgCentrosomes);
        } else {
            print("No nuclei found.");
        }
        print("Centrosomes found: " + numCentrosomes);

        // ------------------------------------------------
        // D. GUARDAR IMAGEN FINAL (TIFF + ROI MANAGER)
        // ------------------------------------------------
        // [cite: 14] PDF: Save an output TIFF image showing segmented nuclei over phase contrast
        
        // 1. Preparar el fondo (Fase)
        selectImage("C1-Input");
        run("RGB Color"); 
        
        // 2. Añadir Centrosomas al ROI Manager (REQUISITO PDF)
        // [cite: 16] PDF: Before saving... add detected centrosomes... output Point Selection... roiManager("add")
        selectImage("C2-Input");
        run("Find Maxima...", "prominence=180 output=[Point Selection]");
        
        if (selectionType() == 10) { // Si hay puntos
            roiManager("Add"); // [cite: 16] Cumplimos el requisito de añadirlos
            
            // Ahora seleccionamos ese último ROI (los puntos) para pintarlo de ROJO
            countROIs = roiManager("count");
            roiManager("Select", countROIs-1);
            roiManager("Set Color", "red");
            roiManager("Set Point Type", "Dot"); // Opcional, para que se vea bien
            roiManager("Set Point Size", "large");
        }
        
        // 3. Visualizar todo sobre la imagen de Fase
        selectImage("C1-Input");
        roiManager("Show All without labels");
        
        // 4. "Aplastar" (Flatten) para fijar el dibujo
        run("Flatten"); 
        
        // 5. Guardar como TIFF (REQUISITO PDF)
        // [cite: 14] PDF: Save an output TIFF image
        saveName = replace(Files[i], ".tif", "") + "_Overlay.tif";
        saveAs("Tiff", OutputFolder + saveName);
        
        print(">> Saved TIFF: " + saveName);
        
        close("C1-Input"); 
        close("C2-Input");
        
        // Limpiar para la siguiente
        run("Close All");
    }
}

// ==================================================
// 3. FINAL PROJECT STATISTICS
// ==================================================
// [cite: 13] PDF: Compute averages for all images at the end
print("\n==========================================");
print("===       FINAL PROJECT SUMMARY        ===");
print("==========================================");
print("Total Images Processed: " + ImageCount);

if (ImageCount > 0) {
    print("Avg Nuclei per Image: " + numAllNuclei/ImageCount);
    print("Avg Centrosomes per Image: " + numAllCentrosomes/ImageCount);
}

if (numAllNuclei > 0) {
    avgAllCentrosomes = numAllCentrosomes / numAllNuclei;
    print("Global Avg Centrosomes per Nucleus: " + avgAllCentrosomes);
    
    pctGlobalElongated = (numAllElongated / numAllNuclei) * 100;
    print("Global % Elongated Nuclei: " + pctGlobalElongated + "%");
}
print("==========================================");

// 0. INITIALIZATION
run("Close All");
run("Clear Results"); 
print("\\Clear");

// Configuración importante (AR incluido)
run("Set Measurements...", "area centroid shape redirect=None decimal=3");

// 1. INPUTS
InputFolder = getDirectory("Select input images folder");
Files = getFileList(InputFolder);

// === NUEVO: Pedimos dónde guardar las imágenes finales ===
OutputFolder = getDirectory("Select output folder to save images");

// Contadores Globales
numAllNuclei = 0;
numAllCentrosomes = 0;
numAllElongated = 0;
ImageCount = 0;

// 2. MAIN LOOP
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
        
        // === IMPORTANTE: NO CERRAMOS C1 (Lo usamos de fondo) ===
        // close("C1-Input"); 
        
        // ------------------------------------------------
        // A. ANALIZAR NÚCLEOS (C3)
        // ------------------------------------------------
        selectImage("C3-Input");
        run("Duplicate...", "title=Mask");
        run("Median...", "radius=1");
        run("Subtract Background...", "rolling=10");
        setAutoThreshold("Yen dark 16-bit no-reset");
        setOption("BlackBackground", true);
        run("Convert to Mask");
        run("Watershed");
        
        run("Analyze Particles...", "display exclude include summarize add measure");
        
        numNuclei = nResults;
        numAllNuclei = numAllNuclei + numNuclei;
        print("Amount of nuclei in image " + ImageCount +": "+ numNuclei);
        
        // Calcular Área y Elongación (Tu lógica con AR)
        totalArea = 0;
        numElongatedLocal = 0;
        
        for (x=0; x<nResults; x++){
            // Area
            valorArea = getResult("Area", x);
            totalArea = totalArea + valorArea;
            
            // Elongación (AR)
            ar = getResult("AR", x);
            if (ar >= 1.6){
                numElongatedLocal = numElongatedLocal + 1;
                // NOTA: Aunque los pintemos de azul aquí en el Manager, 
                // el bloque de guardado de abajo los pintará de amarillo para la foto final
                // tal como pediste en tu código de ejemplo.
                roiManager("select", x);
                roiManager("Set Color", "blue"); 
            }
        }
        roiManager("Deselect");
        
        if (numNuclei > 0){
            avgArea = totalArea/numNuclei;
            print("Average area of all nuclei in image " + ImageCount +": " + avgArea);
        }
        
        print("Amount of elongated nuclei in image " + ImageCount + ": "+ numElongatedLocal);
        
        pctElongated = 0;
        if (numNuclei > 0) {
            pctElongated = (numElongatedLocal / numNuclei) * 100;
        }
        print(pctElongated + " % of nuclei are elongated in image " + ImageCount);
        numAllElongated = numAllElongated + numElongatedLocal;
        
        close("Mask");
        close("C3-Input");
        
        // ------------------------------------------------
        // B. ANALIZAR CENTROSOMAS (C2)
        // ------------------------------------------------
        selectImage("C2-Input");
        // Usamos output=[Point Selection]
        run("Find Maxima...", "prominence=180 output=[Point Selection]");
        
        numCentrosomes = 0;
        if (selectionType() == 10) { 
             getSelectionCoordinates(xpoints, ypoints);
             numCentrosomes = lengthOf(xpoints);
        }
        
        numAllCentrosomes = numAllCentrosomes + numCentrosomes;
        
        print("Number of centrosomes: " + numCentrosomes);
        
        avgCentrosomes = 0;
        if (numNuclei > 0) {
            avgCentrosomes = numCentrosomes / numNuclei;
        }
        print("Average amount of centrosomes per nuclei in image " + ImageCount + ": " + avgCentrosomes);

        // ------------------------------------------------
        // C. GENERAR Y GUARDAR IMAGEN (TIFF + ROI Manager)
        // ------------------------------------------------
        
        // 1. Seleccionar la imagen de Fase (C1) como base
        selectImage("C1-Input");
        run("RGB Color"); 
        
        // 2. Añadir Núcleos al Overlay (Exactamente como tu ejemplo)
        for (n=0; n<numNuclei; n++) {
            roiManager("select", n);
            Overlay.addSelection("yellow", 2); 
        }
        roiManager("Deselect");
        
        // 3. Añadir Centrosomas al Overlay
        selectImage("C2-Input");
        if (selectionType() == 10) {
            
            // --- CAMBIO 1: AÑADIR AL ROI MANAGER (Requisito) ---
            roiManager("Add"); 
            // ---------------------------------------------------

            // Transferimos la selección a la imagen C1
            selectImage("C1-Input");
            run("Restore Selection"); 
            Overlay.addSelection("green", 5); 
            run("Select None"); 
        } else {
            selectImage("C1-Input");
        }
        
        // 4. Aplastar y Guardar
        run("Flatten"); 
        
        // --- CAMBIO 2: GUARDAR EN TIFF (Requisito) ---
        saveName = replace(Files[i], ".tif", "") + "_Overlay.tif"; // Extensión .tif
        saveAs("Tiff", OutputFolder + saveName);               // Formato Tiff
        // ---------------------------------------------
        
        print(">> Saved Image: " + saveName);
        
        close("C1-Input"); 
        close("C2-Input");
        // La imagen Flatten se cierra con Close All abajo

        // waitForUser("Check results");
        run("Close All");
        print("----");
    }
}

// 3. FINAL REPORT
print("-------------------------------------------------------------");
print("The average amount of nuclei over all images is: " + numAllNuclei/ImageCount);
print("The average amount of centrosomes over all images is: "+numAllCentrosomes/ImageCount);

avgAllCentrosomes = 0;
if (numAllNuclei > 0) {
    avgAllCentrosomes = numAllCentrosomes/numAllNuclei;
    print("The average amount of centrosomes per nuclei over all images is: " + avgAllCentrosomes);
    print("The average percentage of elongated nucleis is: "+ (numAllElongated/numAllNuclei)*100 + "%");
}

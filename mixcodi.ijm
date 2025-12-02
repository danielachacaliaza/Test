// Initialization
run("Close All");
run("Clear Results"); 
print("\\Clear");

// Configuración medidas (AR incluido)
run("Set Measurements...", "area centroid shape redirect=None decimal=3");

// Files are parsed from a user picked image folder
InputFolder = getDirectory("Select input images folder");
// 1. NUEVO: Pedir carpeta de salida (Requisito PDF)
OutputFolder = getDirectory("Select output folder to save images");

Files = getFileList(InputFolder);
numAllNuclei = 0;
numAllCentrosomes = 0;
numAllNucleiArea = 0;
numAllElongated = 0;
ImageCount = 0;

// Loop over the images
for(i=0;i<lengthOf(Files);i++)
{
    if (endsWith(Files[i], ".tif") || endsWith(Files[i], ".jpg")) {
    
        ImageCount = ImageCount+1;
        ImagePath = Files[i];
        
        // Limpieza obligatoria
        run("Clear Results");
        roiManager("Reset");
        run("Remove Overlay"); 

        open(InputFolder + ImagePath);
        rename("Input");
        run("Split Channels");
        
        // 2. CAMBIO: Comentamos esto para no borrar el fondo (Requisito PDF)
        // close("C1-Input"); 
        
        // --> Select C3 (Nuclei)
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
        print("\nImage " + ImageCount + ": "+ numNuclei + " nuclei.");

        // Calcular Area y Elongación
        totalArea = 0;
        numElongatedLocal = 0;
        
        for (x=0; x<nResults; x++){
            valorArea = getResult("Area", x);
            totalArea = totalArea + valorArea;
            
            ar = getResult("AR", x);
            
            // Pintamos en el ROI Manager (Tu estilo visual)
            roiManager("select", x);
            if (ar >= 1.6){
                numElongatedLocal = numElongatedLocal + 1;
                roiManager("Set Color", "blue"); // Elongados Azul
            } else {
                roiManager("Set Color", "yellow"); // Normales Amarillo
            }
        }
        roiManager("Deselect");
        
        if (numNuclei>0){
            avgArea = totalArea/numNuclei;
            print("Average Area: " + avgArea);
        }

        pctElongated = 0;
        if (numNuclei > 0) pctElongated = (numElongatedLocal/numNuclei) * 100;
        print(pctElongated + " % elongated nuclei");
        numAllElongated = numAllElongated + numElongatedLocal;
        
        close("Mask");
        close("C3-Input");
        
        // --> Count centrosomes (C2)
        selectImage("C2-Input");
        // Usamos output=Count para contar rápido
        run("Find Maxima...", "prominence=180 output=Count");
        
        numCentrosomes = getResult("Count", nResults-1);
        numAllCentrosomes = numAllCentrosomes + numCentrosomes;
        
        avgCentrosomes = 0;
        if(numNuclei > 0) avgCentrosomes = numCentrosomes/numNuclei;
        
        print("Centrosomes found: " + numCentrosomes);
        print("Ratio Centrosomes/Nuclei: " + avgCentrosomes);

        // ==========================================================
        // 3. NUEVO: BLOQUE "CUMPLE PDF" (Guardar TIFF + ROI Manager)
        // ==========================================================
        
        // A) Añadir Centrosomas al ROI Manager (Requisito PDF explícito)
        selectImage("C2-Input");
        run("Find Maxima...", "prominence=180 output=[Point Selection]");
        if (selectionType() == 10) { 
            roiManager("Add"); // <--- ESTO LO PIDE EL PDF
            
            // Opcional: Pintar el último ROI (los puntos) de rojo para que se vea
            count = roiManager("count");
            roiManager("Select", count-1);
            roiManager("Set Color", "red");
        }
        
        // B) Crear la imagen final sobre el contraste de fase (C1)
        selectImage("C1-Input");
        run("RGB Color"); 
        roiManager("Show All without labels"); // Muestra Amarillos, Azules y Rojos
        run("Flatten"); 
        
        // C) Guardar como TIFF (Requisito PDF explícito)
        saveName = replace(Files[i], ".tif", "") + "_Overlay.tif";
        saveAs("Tiff", OutputFolder + saveName);
        print("Saved TIFF: " + saveName);
        
        close("C1-Input"); 
        close("C2-Input");
        run("Close All");
    }
}

// RESULTADOS FINALES
print("-------------------------------------------------------------");
if (ImageCount > 0) {
    print("Avg Nuclei per image: " + numAllNuclei/ImageCount);
    print("Avg Centrosomes per image: "+numAllCentrosomes/ImageCount);
}

if (numAllNuclei > 0) {
    avgAllCentrosomes = numAllCentrosomes/numAllNuclei;
    print("Avg Centrosomes per nucleus overall: " +avgAllCentrosomes);
    print("Global % elongated nuclei: " + (numAllElongated/numAllNuclei)*100 + "%");
}

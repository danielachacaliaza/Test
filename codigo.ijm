run("Close All");
run("Clear Results"); 
run("Set Measurements...", "area centroid shape redirect=None decimal=3");

InputFolder = getDirectory("Select input images folder");
Files = getFileList(InputFolder);
OutputFolder = getDirectory("Select output folder to save images");

numAllNuclei = 0;
numAllCentrosomes = 0;
numAllElongated = 0;
ImageCount = 0;

for(i=0; i<lengthOf(Files); i++)
{
    run("Clear Results");
    roiManager("Reset");
    
    ImageCount = ImageCount+1;
    ImagePath = Files[i];
    open(InputFolder + ImagePath);
    rename("Input");
    run("Split Channels");
    
    // ANÁLISIS DE NÚCLEOS
    selectImage("C3-Input");
    run("Duplicate...", "title=Mask");
    run("Median...", "radius=1");
    run("Subtract Background...", "rolling=10");
    setAutoThreshold("Yen dark 16-bit no-reset");
    setOption("BlackBackground", true);
    run("Convert to Mask");
    run("Watershed");
    run("Analyze Particles...", "display exclude include summarize add measure");
    
    numNuclei = roiManager("count");
    numAllNuclei = numAllNuclei + numNuclei;
    
    print("Amount of nuclei in image " + ImageCount +": "+ numNuclei);
    
    totalArea = 0;
    numElongated = 0;
    
    for (x=0; x<numNuclei; x++){
        valorArea = getResult("Area", x);
        totalArea = totalArea + valorArea;
        ar = getResult("AR", x);
        if (ar >= 1.6){
            numElongated = numElongated+1;
        }
    }
    
    avgArea = totalArea/numNuclei;
    print("Average area of nuclei in image " + ImageCount +": " + avgArea);
    print("Amount of elongated nuclei in image " + ImageCount + ": "+numElongated);
    
    pctElongated = (numElongated/numNuclei) * 100;
    print(pctElongated + " % elongated nuclei");
    numAllElongated = numAllElongated + numElongated;
    
    // Poner núcleos en amarillo
    for (r=0; r<numNuclei; r++){
        roiManager("Select", r);
        roiManager("Set Color", "yellow");
        roiManager("Set Line Width", 2);
    }
    
    // ANÁLISIS DE CENTROSOMAS
    selectImage("C2-Input");
    run("Find Maxima...", "prominence=180 output=[List]");
    numCentrosomes = nResults;
    run("Find Maxima...", "prominence=180 output=[Single Points]");
    run("Create Selection");
    roiManager("Add");
    print("Centrosomes: " + numCentrosomes);
    numAllCentrosomes = numAllCentrosomes + numCentrosomes;
    
    avgCentrosomes = numCentrosomes/numNuclei;
    print("Average centrosomes per nucleus in image " + ImageCount + ": " + avgCentrosomes);
    
    // Poner centrosomas en azul
    roiManager("Select", numNuclei);
    roiManager("Set Color", "cyan");
    
    // VISUALIZACIÓN
    selectImage("C1-Input");
    run("RGB Color");
    roiManager("Show All without labels");
    run("Flatten");
    
    saveAs("Tiff", OutputFolder + "Analyzed_" + ImagePath);
    run("Close All");
    print("----");
}

// RESULTADOS FINALES
print("-------------------------------------------------------------");
print("Average nuclei per image: " + numAllNuclei/ImageCount);
print("Average centrosomes per image: " + numAllCentrosomes/ImageCount);

avgAllCentrosomes = numAllCentrosomes/numAllNuclei;
print("Average centrosomes per nucleus overall: " + avgAllCentrosomes);
print("Average % elongated nuclei: " + (numAllElongated/numAllNuclei)*100 + "%");


// Initialization
// --> Record and add the line to "Set measurements" to Area, Shape descriptor and Mean gray value
run("Close All");
run("Clear Results"); 
print("\\Clear");

// IMPRESCINDIBLE PARA EL PDF: "shape" activa la columna AR
run("Set Measurements...", "area centroid shape redirect=None decimal=3");

// Files are parsed from a user picked image folder
InputFolder = getDirectory("Select input images folder");

// === NUEVO (PDF): Pedir carpeta de salida ===
OutputFolder = getDirectory("Select output folder to save images"); 

Files = getFileList(InputFolder);
numAllNuclei = 0;
numAllCentrosomes = 0;
numAllNucleiArea = 0;
numAllElongated = 0;
ImageCount = 0;

// Loop over the images from the input folder
for(i=0;i<lengthOf(Files);i++)
{
	if (endsWith(Files[i], ".tif") || endsWith(Files[i], ".jpg")) { // Filtro añadido por seguridad
		
		ImageCount = ImageCount+1;
		ImagePath = Files[i];
		
		// LIMPIEZA (Tuya + necesaria)
		run("Clear Results");
		roiManager("Reset");
		run("Remove Overlay"); 

		open(InputFolder + ImagePath); //Nose aixo
		rename("Input");
		run("Split Channels");
		
		// === CAMBIO (PDF): Comentamos esto para no cerrar el fondo ===
		// close("C1-Input");
		
		// --> Select the Channel 3 image and duplicate it (name the new image "Mask")
		selectImage("C3-Input");
		run("Duplicate...", "title=Mask");
		// --> Apply an appropriate sequence of operations to obtain a binary mask of the nuclei
		run("Median...", "radius=1");
		run("Subtract Background...", "rolling=10");
		setAutoThreshold("Yen dark 16-bit no-reset");
		setOption("BlackBackground", true);
		run("Convert to Mask");
		run("Watershed");
		
		// --> Analyze connected particles in the nuclei mask and store the objects in the ROI Manager
		run("Analyze Particles...", "display exclude include summarize add measure");
		numNuclei = nResults;
		numAllNuclei = numAllNuclei + numNuclei;
		print("Amount of nuclei in image " + ImageCount +": "+ numNuclei);
		
		// --> Close the mask and display the ROIs (selections) over Channel 2 image
		// 3. Average area of nuclei (TU PRIMER BUCLE)
		totalArea = 0;
		for (x=0; x<nResults; x++){
			valorArea = getResult("Area", x);
			totalArea = totalArea + valorArea;
		}
		if (numNuclei>0){
			avgArea = totalArea/numNuclei;
			print("Average area of all nuclei in image " + ImageCount +": " + avgArea);
		}
		
		run("Clear Results"); // Limpias tabla para medir elongación
		run("Analyze Particles...", "display exclude include summarize add measure");
		
		// How many elongated nuclei (TU SEGUNDO BUCLE)
		numElongated = 0;
		for (t = 0; t < nResults;t++){
			ar = getResult("AR", t);
			if (ar >= 1.6){
				numElongated = numElongated+1;
				roiManager("select", t);
				roiManager("Set Color", "blue"); // AIXO ESTA CANVIAT (Tu estilo)
				roiManager("Set Line Width", 2);
			} else {
				// El resto en amarillo (Para que quede bien en la foto)
				roiManager("select", t);
				roiManager("Set Color", "yellow"); 
				roiManager("Set Line Width", 2);
			}
		}
		roiManager("Deselect");
		
		print("Amount of elongated nuclei in image " + ImageCount + ": "+numElongated);
		pctElongated = 0;
		if (numNuclei > 0) pctElongated = (numElongated/numNuclei) * 100;
		print(pctElongated + " % of nuclei are elongated in image "+ImageCount);
		numAllElongated = numAllElongated + numElongated;
		
		
		// Count centrosomes
		close("Mask");     // Cierro Mask para limpiar
		close("C3-Input"); // Cierro C3 para limpiar
		
		selectImage("C2-Input");
		// Usamos LIST para contar (como tenías tú)
		run("Find Maxima...", "prominence=180 output=[List]");
		numCentrosomes = nResults; 
		
		// NOTA: Find Maxima [List] borra la tabla Results, por eso la usamos al final. Correcto.
		
		numAllCentrosomes = numAllCentrosomes + numCentrosomes;
		avgCentrosomes = 0;
		if (numNuclei > 0) avgCentrosomes = numCentrosomes/numNuclei;
		
		print("Average amount of centrosomes per nuclei in image " + ImageCount + ": " + avgCentrosomes);
		
		// ==========================================================
		// === AÑADIDO OBLIGATORIO PARA CUMPLIR EL PDF ===
		// ==========================================================
		
		[cite_start]// 1. Añadir Centrosomas al ROI Manager (PDF Requisito [cite: 16])
		selectImage("C2-Input");
		run("Find Maxima...", "prominence=180 output=[Point Selection]");
		if (selectionType() == 10) {
			roiManager("Add"); // <--- ESTO ES LO QUE PIDE EL PDF
			
			// Los ponemos rojos para que se vean
			last = roiManager("count");
			roiManager("Select", last-1);
			roiManager("Set Color", "red");
		}
		
		[cite_start]// 2. Crear Imagen Final sobre Fase (C1) [cite: 14]
		selectImage("C1-Input");
		run("RGB Color"); 
		roiManager("Show All without labels");
		run("Flatten");
		
		[cite_start]// 3. Guardar como TIFF [cite: 14]
		saveName = replace(Files[i], ".tif", "") + "_Overlay.tif";
		saveAs("Tiff", OutputFolder + saveName);
		print("Saved: " + saveName);
		
		close("C1-Input");
		close("C2-Input");
		// ==========================================================
		
		// waitForUser("Check the results");
		run("Close All");
		print("----");
	}
}

print("-------------------------------------------------------------");
if (ImageCount > 0) {
	print("The average amount of nuclei over all images is: " + numAllNuclei/ImageCount);
	print("The average amount of centrosomes over all images is: "+numAllCentrosomes/ImageCount);
}

if (numAllNuclei > 0) {
	avgAllCentrosomes = numAllCentrosomes/numAllNuclei;
	print("The average amount of centrosomes per nuclei over all images is: " +avgAllCentrosomes);
	print("The average percentage of elongated nucleis is: "+ (numAllElongated/numAllNuclei)*100);
}

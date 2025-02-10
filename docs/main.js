function addFunctionElement(funcName, description, paramsList=[], returnList=[]) {
    // Get the template
    let template = document.getElementById("function-template");

    if (!template) {
        console.error("Template element not found!");
        return;
    }

    // Clone the template content
    let newElement = template.content.cloneNode(true);

    // Modify cloned content
    newElement.querySelector(".function-name").textContent = funcName;
    newElement.querySelector(".description").textContent = description;

    let detailsElement = newElement.querySelector("details");

    if (paramsList.length > 0) {
        let paramsHTML = paramsList.map(param => `<li>${param}</li>`).join("");
        let paramsContainer = document.createElement("ul");
        paramsContainer.classList.add("params");
        paramsContainer.innerHTML = paramsHTML;

        let paramsLabel = document.createElement("p");
        paramsLabel.classList.add("params-label");
        paramsLabel.textContent = "@params:";

        detailsElement.appendChild(paramsLabel);
        detailsElement.appendChild(paramsContainer);
    }

    if (returnList.length > 0) {
        let paramsHTML = paramsList.map(param => `<li>${param}</li>`).join("");
        let paramsContainer = document.createElement("ul");
        paramsContainer.classList.add("returns");
        paramsContainer.innerHTML = paramsHTML;

        let paramsLabel = document.createElement("p");
        paramsLabel.classList.add("returns-label");
        paramsLabel.textContent = "@return:";

        detailsElement.appendChild(paramsLabel);
        detailsElement.appendChild(paramsContainer);
    }

    // Append to body
    document.body.appendChild(newElement);
}

function addLabelElement(labelName, labelClass=null) {
    // Get the template
    let template = document.getElementById("label-template");

    if (!template) {
        console.error("Template element not found!");
        return;
    }

    // Clone the template content
    let newElement = template.content.cloneNode(true);

    // Modify cloned content
    let labelElement = newElement.querySelector(".label")
    labelElement.textContent = labelName;
    if (labelClass) {
        labelElement.classList.add(labelClass)
    }

    // Append to body
    document.body.appendChild(newElement);
}

async function loadFunctionsFromJSON(url) {
    try {
        // Fetch the JSON file
        let response = await fetch(url);
        if (!response.ok) throw new Error(`Failed to load JSON: ${response.statusText}`);

        // Parse the JSON
        let data = await response.json();

        // Iterate over the functions in the JSON (adjust for your structure)
        for (let folder in data) {
            addLabelElement(folder);
            for (let file in data[folder]) {
                addLabelElement(file, "padded");
                for (let functionName in data[folder][file]) {
                    let func = data[folder][file][functionName];
                    
                    addFunctionElement(functionName, func.description, func.params, func.return);
                }
            }
        }
    } catch (error) {
        console.error("Error loading JSON:", error);
    }
}

// Call the function with the path to your JSON file
loadFunctionsFromJSON("docs/docs.json");

// Example usage:
// addLabelElement("example");
// addFunctionElement("myFunction", "This is a test function.", ["[#] Bytes to print", "[&] Buffer pointer"]);

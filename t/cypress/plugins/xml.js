const fs = require("fs");
const path = require("path");
const { exec } = require("child_process");
const { promisify } = require("util");
const execPromise = promisify(exec);

async function modifyXmlElement({ filePath, element, value }) {
    const targetPath = path.resolve(filePath);
    let xmlContent;

    try {
        xmlContent = fs.readFileSync(targetPath, "utf8");
        const regex = new RegExp(`<${element}>[^<]*</${element}>`, "i");
        const replacement = `<${element}>${value}</${element}>`;

        if (!regex.test(xmlContent)) {
            throw new Error(`Element <${element}> not found in ${targetPath}`);
        }

        const newContent = xmlContent.replace(regex, replacement);
        fs.writeFileSync(targetPath, newContent, "utf8");

        await execPromise("flush_memcached");
        await execPromise("koha-plack --restart kohadev");
        return null;
    } catch (err) {
        return err.message;
    }
}

async function readXmlElementValue({ filePath, element }) {
    const targetPath = path.resolve(filePath);
    let xmlContent;

    try {
        xmlContent = fs.readFileSync(targetPath, "utf8");
        const regex = new RegExp(`<${element}>([^<]*)</${element}>`, "i");
        const match = xmlContent.match(regex);

        if (!match) {
            throw new Error(`Element <${element}> not found in ${targetPath}`);
        }

        // Return the value of the element
        return match[1]; // match[1] contains the value between the tags
    } catch (err) {
        return err.message;
    }
}

module.exports = { readXmlElementValue, modifyXmlElement };

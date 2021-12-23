import fs from "fs";

export async function writeFile<T>(file: string, data: string): Promise<any> {
  return new Promise((resolve, reject) => {
    fs.writeFile(file, data, (err) => {
      return err ? reject(err) : console.log(err); // XXXS `!`
    });
  });
}

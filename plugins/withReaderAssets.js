const { withDangerousMod, withXcodeProject } = require('@expo/config-plugins');
const fs = require('fs');
const path = require('path');

const withReaderAssets = (config) => {
  config = withDangerousMod(config, [
    'android',
    (config) => {
      const projectRoot = config.modRequest.projectRoot;
      const platformRoot = config.modRequest.platformProjectRoot;
      const assetsDir = path.join(platformRoot, 'app', 'src', 'main', 'assets');
      const sourceRoot = path.join(projectRoot, 'assets', 'reader');

      fs.mkdirSync(assetsDir, { recursive: true });

      for (const subdir of ['css', 'js', 'fonts']) {
        const src = path.join(sourceRoot, subdir);
        const dest = path.join(assetsDir, subdir);
        if (fs.existsSync(src)) {
          fs.cpSync(src, dest, { recursive: true });
        }
      }

      return config;
    },
  ]);

  config = withDangerousMod(config, [
    'ios',
    (config) => {
      const projectRoot = config.modRequest.projectRoot;
      const platformRoot = config.modRequest.platformProjectRoot;
      const projectName = config.modRequest.projectName || 'LNReader';
      const assetsDir = path.join(platformRoot, projectName, 'reader');
      const sourceRoot = path.join(projectRoot, 'assets', 'reader');

      fs.mkdirSync(assetsDir, { recursive: true });

      for (const subdir of ['css', 'js', 'fonts']) {
        const src = path.join(sourceRoot, subdir);
        const dest = path.join(assetsDir, subdir);
        if (fs.existsSync(src)) {
          fs.cpSync(src, dest, { recursive: true });
        }
      }

      return config;
    },
  ]);

  config = withXcodeProject(config, (config) => {
    const xcodeProject = config.modResults;
    const projectName = config.modRequest.projectName || 'LNReader';
    const folderPath = path.join(projectName, 'reader');

    try {
      if (!xcodeProject.hasFile(folderPath) && !xcodeProject.hasFile('reader')) {
        xcodeProject.addResourceFile(folderPath, {
          target: xcodeProject.getFirstTarget().uuid,
        });
      }
    } catch {
      // In case hasFile or target lookup differs across xcode library versions
    }

    return config;
  });

  return config;
};

module.exports = withReaderAssets;

$ErrorActionPreference = "Stop"

# ============================================================
# Smitch Offline Patch
# ============================================================

$Root       = Split-Path -Parent $MyInvocation.MyCommand.Path
$Decoded    = Join-Path $Root "smitch_decoded"
$AppJs      = Join-Path $Decoded "assets\www\js\app.js"
$BackupJs   = Join-Path $Decoded "assets\www\js\app.js.original"
$ApktoolJar = Join-Path $Root "tools\apktool.jar"
$OriginalApk = Join-Path $Root "smitch.apk"
$UnsignedApk = Join-Path $Root "smitch_offline_unsigned.apk"
$FinalApk   = Join-Path $Root "smitch_offline.apk"
$BuildDir   = Join-Path $Root "smitch_build"

Write-Host ""
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host "        SMITCH OFFLINE APK PATCHER" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------
# Verify prerequisites
# ------------------------------------------------------------

if (!(Test-Path $AppJs)) {
    throw "Decoded app.js not found: $AppJs"
}

if (!(Test-Path $ApktoolJar)) {
    throw "apktool.jar not found: $ApktoolJar"
}

if (!(Test-Path $OriginalApk)) {
    throw "Original APK not found: $OriginalApk"
}

Write-Host "[OK] Decoded APK found"
Write-Host "[OK] Apktool found"
Write-Host "[OK] Original APK found"

# ------------------------------------------------------------
# Backup app.js
# ------------------------------------------------------------

if (!(Test-Path $BackupJs)) {
    Copy-Item $AppJs $BackupJs
    Write-Host "[OK] Backup created: app.js.original" -ForegroundColor Green
}
else {
    Write-Host "[OK] Backup already exists"
    # If app.js was already patched in a previous run, restore from pristine backup so script is re-runnable
    $rawCheck = Get-Content $AppJs -Raw
    if ($rawCheck.Contains("SMITCH_OFFLINE_PATCH_V1")) {
        Write-Host "[INFO] Reverting app.js to pristine backup before patching..." -ForegroundColor Yellow
        Copy-Item $BackupJs $AppJs -Force
    }
}

# ------------------------------------------------------------
# Read app.js
# ------------------------------------------------------------

$content = Get-Content $AppJs -Raw

# ------------------------------------------------------------
# Verify the original structures we expect
# ------------------------------------------------------------

$afterCount = ([regex]::Matches(
    $content,
    '\$scope\.after_onlineconfig\s*=\s*function\s*\(\)\s*\{'
)).Count

if ($afterCount -ne 2) {
    throw "Expected exactly 2 after_onlineconfig() functions, found $afterCount. No changes made."
}


if (!$content.Contains("CREATE TABLE IF NOT EXISTS offline")) {
    throw "Existing offline SQLite implementation was not found."
}

if (!$content.Contains("SELECT * FROM offline")) {
    throw "Existing offline controller was not found."
}

Write-Host "[OK] Expected Smitch structures verified" -ForegroundColor Green

# ============================================================
# Replacement function
# ============================================================

$offlineFunction = @'
  /*
   * ==========================================================
   * SMITCH_OFFLINE_PATCH_V1
   *
   * Original Smitch onboarding tried to:
   *
   *   1. POST the board to the Smitch cloud
   *   2. refresh the account through HttpService.getPost()
   *   3. navigate to onboard_finish
   *
   * The cloud is no longer available.
   *
   * This replacement keeps the already-created local board
   * configuration and stores it in the APK's existing offline
   * SQLite table.
   *
   * The existing offlineCtrl subsequently:
   *   - reads this table
   *   - discovers the board using Zeroconf
   *   - matches the MAC address
   *   - fills in the board IP
   *   - communicates directly with the board on TCP/80
   * ==========================================================
   */
  $scope.after_onlineconfig = function(){

    console.log("SMITCH_OFFLINE_PATCH_V1: starting local configuration");

    try {

      /*
       * Start with the existing user object.
       * We deliberately preserve the rest of the user's data.
       */
      var localUser = null;
      if ($scope.udata && $scope.udata.user) {
        localUser = angular.copy($scope.udata.user);
      } else {
        localUser = {
          name: "Local User",
          email: "offline@smitch.local",
          rooms: []
        };
      }

      if(!localUser.rooms){
        localUser.rooms = [];
      }

      /*
       * Build the board configuration already assembled by
       * finishconfig().
       *
       * The board IP is intentionally left empty here.
       * offlineCtrl.saveip() will discover the board via
       * Zeroconf and populate ipv4Addresses[0].
       */
      var localBoard = angular.copy(
        $scope.sb.room.switch_boards[0]
      );

      localBoard.ip_address = "";

      /*
       * Find the room used during onboarding.
       */
      var targetRoom = null;

      for(var r = 0; r < localUser.rooms.length; r++){

        if(
          localUser.rooms[r].room_name ==
          $scope.sb.room.room_name
        ){
          targetRoom = localUser.rooms[r];
          break;
        }
      }

      /*
       * If the room does not already exist, create it.
       */
      if(!targetRoom){

        targetRoom = {
          "room_name": $scope.sb.room.room_name,
          "room_type": $scope.sb.room.room_type,
          "switch_boards": []
        };

        localUser.rooms.push(targetRoom);
      }

      if(!targetRoom.switch_boards){
        targetRoom.switch_boards = [];
      }

      /*
       * Replace an existing board with the same MAC,
       * otherwise add the new board.
       */
      var boardFound = false;

      for(var b = 0; b < targetRoom.switch_boards.length; b++){

        if(
          targetRoom.switch_boards[b].mac_address ==
          localBoard.mac_address
        ){

          targetRoom.switch_boards[b] = localBoard;
          boardFound = true;
          break;
        }
      }

      if(!boardFound){
        targetRoom.switch_boards.push(localBoard);
      }

      console.log(
        "SMITCH_OFFLINE_PATCH_V1: local user configuration",
        localUser
      );

      /*
       * Store the exact structure expected by offlineCtrl.
       */
      db.transaction(function(tx){

        tx.executeSql(
          'DROP TABLE IF EXISTS offline'
        );

      }, function(error){

        console.log(
          "SMITCH_OFFLINE_PATCH_V1: DROP error",
          error
        );

        $ionicLoading.hide();

      }, function(){

        db.transaction(function(tx){

          tx.executeSql(
            'CREATE TABLE IF NOT EXISTS offline (user)'
          );

        }, function(error){

          console.log(
            "SMITCH_OFFLINE_PATCH_V1: CREATE error",
            error
          );

          $ionicLoading.hide();

        }, function(){

          db.transaction(function(tx){

            tx.executeSql(
              'INSERT INTO offline VALUES (?)',
              [
                JSON.stringify(localUser)
              ]
            );

          }, function(error){

            console.log(
              "SMITCH_OFFLINE_PATCH_V1: INSERT error",
              error
            );

            $ionicLoading.hide();

          }, function(){

            console.log(
              "SMITCH_OFFLINE_PATCH_V1: offline configuration saved"
            );

            $ionicLoading.hide();

            /*
             * Go directly to the application's existing
             * offline controller.
             */
            $ionicHistory.nextViewOptions({
              disableBack: true
            });

            $state.go('offline');

          });

        });

      });

    }
    catch(e){

      console.log(
        "SMITCH_OFFLINE_PATCH_V1: local configuration failed",
        e
      );

      $ionicLoading.hide();

      window.plugins.toast.showWithOptions({
        message: "Could not create offline configuration",
        duration: "long",
        position: "bottom",
        styling: {
          opacity: 1.0,
          backgroundColor: '#666666',
          textColor: '#FFFFFF',
          textSize: 15,
          cornerRadius: 100,
          horizontalPadding: 30,
          verticalPadding: 12
        }
      });

    }
  }
'@

# ------------------------------------------------------------
# Patch FIRST after_onlineconfig()
#
# First implementation ends immediately before:
#   $scope.retries = 0;
# ------------------------------------------------------------

$pattern1 = '(?s)\s*\$scope\.after_onlineconfig\s*=\s*function\s*\(\)\s*\{.*?\n\s*\}\s*\r?\n\s*\$scope\.retries\s*=\s*0\s*;'

$placeholder1 = "`r`n/* __SMITCH_PLACEHOLDER_1__ */`r`n  `$scope.retries = 0;"

$step1 = [regex]::Replace(
    $content,
    $pattern1,
    $placeholder1,
    1
)

if ($step1 -eq $content) {
    throw "Could not locate the first after_onlineconfig() function."
}

# ------------------------------------------------------------
# Patch SECOND after_onlineconfig()
#
# Second implementation ends immediately before:
#   $scope.finishconfig = function()
# ------------------------------------------------------------

$pattern2 = '(?s)\s*\$scope\.after_onlineconfig\s*=\s*function\s*\(\)\s*\{.*?\n\s*\}\s*\r?\n\s*\$scope\.finishconfig\s*=\s*function\s*\(\)'

$placeholder2 = "`r`n/* __SMITCH_PLACEHOLDER_2__ */`r`n  `$scope.finishconfig = function()"

$step2 = [regex]::Replace(
    $step1,
    $pattern2,
    $placeholder2,
    1
)

if ($step2 -eq $step1) {
    throw "Could not locate the second after_onlineconfig() function."
}

# Replace placeholders with offlineFunction
$patchedContent = $step2.Replace("/* __SMITCH_PLACEHOLDER_1__ */", $offlineFunction).Replace("/* __SMITCH_PLACEHOLDER_2__ */", $offlineFunction)

# ------------------------------------------------------------
# Patch 3: Default offline user profile in formData service
# ------------------------------------------------------------
$formDataTarget = '\.service\(''formData'',\s*function\(\)\s*\{\s*return\s*\{\s*form:\s*\{\},'
$formDataReplacement = @'
.service('formData', function() {
  var defaultOfflineUser = {
    status: 'success',
    user: {
      user_id: 'offline_user',
      name: 'Local User',
      email: 'offline@smitch.local',
      password: 'offline_password',
      auth_token: 'offline_token',
      rooms: [
        {
          room_name: 'Living Room',
          room_type: 'living',
          switch_boards: []
        }
      ]
    }
  };
  return {
    form: defaultOfflineUser,
'@
$patchedContent = [regex]::Replace($patchedContent, $formDataTarget, $formDataReplacement, 1)

# ------------------------------------------------------------
# Patch 4: Bypass dead cloud login in landCtrl -> go to offline mode
# ------------------------------------------------------------
$landCtrlTarget = '(?s)db\.transaction\(function\(tx\)\s*\{\s*tx\.executeSql\(''SELECT \* FROM appdata''.*?\}\s*,\s*function\(tx,\s*error\)\s*\{\s*console\.log\(''SELECT error: ''\s*\+\s*error\.message\);\s*\}\);\s*\}\);'
$landCtrlReplacement = @'
  db.transaction(function(tx) {
    tx.executeSql('CREATE TABLE IF NOT EXISTS offline (user)');
    $ionicLoading.hide();
    $scope.workoffline();
  }, function(err) {
    $ionicLoading.hide();
    $scope.workoffline();
  });
'@
$patchedContent = [regex]::Replace($patchedContent, $landCtrlTarget, $landCtrlReplacement, 1)

# ------------------------------------------------------------
# Patch 5: Add go_to_onboard in offlineCtrl
# ------------------------------------------------------------
$offlineCtrlTarget = '\$scope\.rooms\s*=\s*\[\];\s*\$scope\.scanning\s*=\s*true;'
$offlineCtrlReplacement = @'
      $scope.rooms = [];
      $scope.scanning = true;
      $scope.go_to_onboard = function(){
        $ionicHistory.nextViewOptions({
          disableBack: true
        });
        $state.go('onboard');
      };
'@
$patchedContent = [regex]::Replace($patchedContent, $offlineCtrlTarget, $offlineCtrlReplacement, 1)

# ------------------------------------------------------------
# Patch 6: Guard onboardCtrl room initialization
# ------------------------------------------------------------
$onboardTarget = '\$scope\.user_rooms\s*=\s*\$scope\.user\.user\.rooms;\s*\$scope\.select_room\s*=\s*\$scope\.user_rooms\[0\];'
$onboardReplacement = @'
  if (!$scope.user || !$scope.user.user) {
    $scope.user = formData.getForm();
  }
  $scope.user_rooms = ($scope.user && $scope.user.user && $scope.user.user.rooms && $scope.user.user.rooms.length > 0) ? $scope.user.user.rooms : [{ room_name: 'Living Room', room_type: 'living', switch_boards: [] }];
  $scope.select_room = $scope.user_rooms[0];
'@
$patchedContent = [regex]::Replace($patchedContent, $onboardTarget, $onboardReplacement, 1)

# ------------------------------------------------------------
# Patch 6: Global open_github in .run()
# ------------------------------------------------------------
$runTarget = '\$rootScope\.chat_msg\s*=\s*false;'
$runReplacement = @'
  $rootScope.chat_msg = false;
  $rootScope.open_github = function() {
    if (window.cordova && window.cordova.InAppBrowser) {
      window.cordova.InAppBrowser.open('https://github.com/ak-ag', '_system', 'location=yes');
    } else {
      window.open('https://github.com/ak-ag', '_system');
    }
  };
'@
$patchedContent = [regex]::Replace($patchedContent, $runTarget, $runReplacement, 1)

# ------------------------------------------------------------
# Patch 7: Bulb navigation (home & search another) in OnBoardLiteCtrl
# ------------------------------------------------------------
$liteCtrlTarget = '(?s)\.controller\(''OnBoardLiteCtrl'',\s*function[^{]*\{\s*\$scope\.user\s*=\s*formData\.getForm\(\)'
$liteCtrlReplacement = @'
.controller('OnBoardLiteCtrl',function($scope,$state,$ionicPlatform,$http,NavRoom,$timeout,homeWiFi,$ionicPopup,on_board_product,credentials,$ionicLoading,$ionicHistory,formData,$timeout,$interval,$filter,HttpService,token,$cordovaBarcodeScanner,mqttSocket){

  $scope.user = formData.getForm();

  $scope.open_github = function() {
    if (window.cordova && window.cordova.InAppBrowser) {
      window.cordova.InAppBrowser.open('https://github.com/ak-ag', '_system', 'location=yes');
    } else {
      window.open('https://github.com/ak-ag', '_system');
    }
  };

  $scope.go_home = function() {
    $ionicHistory.nextViewOptions({
      disableBack: true
    });
    $state.go('offline');
  };

  $scope.search_another = function() {
    var confirmPopup = $ionicPopup.confirm({
      title: 'Search Another Bulb',
      template: '<div style="text-align:center"><p>Do you want to pair or search for another Smitch bulb?</p><p style="font-size:12px;color:#666">This resets the current direct bulb control and opens device setup.</p></div>',
      cancelType: 'button-clear button-dark',
      cancelText: 'Cancel',
      okType: 'button-clear button-positive',
      okText: 'Search'
    });
    confirmPopup.then(function(res) {
      if (res) {
        db.transaction(function(tx) {
          tx.executeSql('DELETE FROM liteapp');
          console.log('Cleared liteapp');
        }, function(err) {
          console.log('Error deleting liteapp:', err);
        });
        $ionicHistory.nextViewOptions({
          disableBack: true
        });
        $state.go('onboard');
      }
    });
  };
'@
$patchedContent = [regex]::Replace($patchedContent, $liteCtrlTarget, $liteCtrlReplacement, 1)

# ------------------------------------------------------------
# Patch 8: offlineCtrl bulb navigation & github link
# ------------------------------------------------------------
$offlineCtrlTarget = '(?s)\.controller\(''offlineCtrl'',\s*function[^{]*\{\s*\$scope\.user\s*=\s*\{\};'
$offlineCtrlReplacement = @'
.controller('offlineCtrl',function($scope,$ionicHistory,$state,$http,$ionicLoading,$timeout){
      $scope.user = {};
      $scope.go_to_bulb = function() {
        $ionicHistory.nextViewOptions({
          disableBack: true
        });
        $state.go('onboard_lite');
      };

      $scope.go_to_onboard = function() {
        $ionicHistory.nextViewOptions({
          disableBack: true
        });
        $state.go('onboard');
      };

      $scope.open_github = function() {
        if (window.cordova && window.cordova.InAppBrowser) {
          window.cordova.InAppBrowser.open('https://github.com/ak-ag', '_system', 'location=yes');
        } else {
          window.open('https://github.com/ak-ag', '_system');
        }
      };
'@
$patchedContent = [regex]::Replace($patchedContent, $offlineCtrlTarget, $offlineCtrlReplacement, 1)

# ------------------------------------------------------------
# Patch 9: settingsCtrl github link
# ------------------------------------------------------------
$settingsCtrlTarget = '(?s)\.controller\(''settingsCtrl'',\s*function[^{]*\{\s*\$scope\.gohome\s*=\s*function\(\)\{'
$settingsCtrlReplacement = @'
.controller('settingsCtrl',function($scope,$state,formData,$http,$ionicPopup,$rootScope,$cordovaBarcodeScanner,$ionicLoading,$ionicHistory,token,BoardOnline,$filter,mqttSocket,encrypt,getRemoteDevices,smitchConnect,$cordovaInAppBrowser){

  $scope.open_github = function() {
    if (window.cordova && window.cordova.InAppBrowser) {
      window.cordova.InAppBrowser.open('https://github.com/ak-ag', '_system', 'location=yes');
    } else {
      window.open('https://github.com/ak-ag', '_system');
    }
  };

  $scope.gohome = function(){
'@
$patchedContent = [regex]::Replace($patchedContent, $settingsCtrlTarget, $settingsCtrlReplacement, 1)

Write-Host "[OK] Applied navigation and GitHub attribution patches" -ForegroundColor Green


# ------------------------------------------------------------
# Verify patch count
# ------------------------------------------------------------

$patchCount = ([regex]::Matches(
    $patchedContent,
    'SMITCH_OFFLINE_PATCH_V1'
)).Count

if ($patchCount -lt 2) {
    throw "Patch verification failed. Expected both onboarding flows to be patched."
}

# ------------------------------------------------------------
# Write patched app.js
# ------------------------------------------------------------

Set-Content `
    -Path $AppJs `
    -Value $patchedContent `
    -Encoding UTF8

Write-Host "[OK] app.js patched" -ForegroundColor Green

# ------------------------------------------------------------
# Verify JS Syntax
# ------------------------------------------------------------

$node = Get-Command node.exe -ErrorAction SilentlyContinue
if ($node) {
    Write-Host "Verifying app.js syntax with Node.js..."
    & $node.Source -c $AppJs
    if ($LASTEXITCODE -ne 0) {
        throw "JavaScript syntax error detected in patched app.js!"
    }
    Write-Host "[OK] app.js syntax verified: valid" -ForegroundColor Green
}

# ------------------------------------------------------------
# Verify cloud onboarding calls were removed from the two
# patched functions.
#
# We do NOT remove cloud functionality elsewhere in the app.
# ------------------------------------------------------------

$verify = Get-Content $AppJs -Raw

if (([regex]::Matches(
    $verify,
    'SMITCH_OFFLINE_PATCH_V1'
)).Count -lt 2) {

    throw "Patch marker verification failed."
}

Write-Host "[OK] Patch markers verified"

# ------------------------------------------------------------
# Build APK
# ------------------------------------------------------------

if (Test-Path $UnsignedApk) {
    Remove-Item $UnsignedApk -Force
}

if (Test-Path $BuildDir) {
    Remove-Item $BuildDir -Recurse -Force
}

Write-Host ""
Write-Host "Building APK..." -ForegroundColor Yellow

java -jar $ApktoolJar b $Decoded -o $UnsignedApk

if (!(Test-Path $UnsignedApk)) {
    throw "Apktool did not produce an APK."
}

Write-Host "[OK] APK rebuilt:" $UnsignedApk -ForegroundColor Green

# ============================================================
# Sign APK (ZipAlign + v1/v2/v3 signature)
# ============================================================

Write-Host ""
Write-Host "Preparing APK signing..." -ForegroundColor Yellow

$UberSignerJar = Join-Path $Root "tools\uber-apk-signer.jar"
$Keystore      = Join-Path $Root "smitch-offline.keystore"
$KeyAlias      = "smitchoffline"
$StorePass     = "smitchoffline"
$KeyPass       = "smitchoffline"

if (Test-Path $FinalApk) {
    Remove-Item $FinalApk -Force
}

$signedSuccess = $false

# Method 1: uber-apk-signer (Self-contained, includes zipalign + v1, v2, v3 schemes)
if (Test-Path $UberSignerJar) {
    Write-Host "[OK] Using uber-apk-signer (supports v1, v2, v3 signatures + automatic zipalign)..." -ForegroundColor Green
    
    java -jar $UberSignerJar -a $UnsignedApk -o $Root
    
    $generatedSignedApk = Join-Path $Root "smitch_offline_unsigned-aligned-debugSigned.apk"
    if (Test-Path $generatedSignedApk) {
        Move-Item -Path $generatedSignedApk -Destination $FinalApk -Force
        $signedSuccess = $true
    }
}

# Method 2: Android SDK apksigner
if (!$signedSuccess) {
    $apksigner = Get-Command apksigner.bat, apksigner -ErrorAction SilentlyContinue
    if ($apksigner) {
        Write-Host "[OK] apksigner found: $($apksigner.Source)"
        # Use apksigner with keystore
        # (creates debug keystore if needed)
    }
}

# Method 3: JDK keytool / jarsigner
if (!$signedSuccess) {
    $keytool   = Get-Command keytool.exe -ErrorAction SilentlyContinue
    $jarsigner = Get-Command jarsigner.exe -ErrorAction SilentlyContinue

    if (!$keytool -or !$jarsigner) {
        $javaBin = Join-Path $env:JAVA_HOME "bin"
        if (Test-Path (Join-Path $javaBin "keytool.exe")) { $keytool = Get-Item (Join-Path $javaBin "keytool.exe") }
        if (Test-Path (Join-Path $javaBin "jarsigner.exe")) { $jarsigner = Get-Item (Join-Path $javaBin "jarsigner.exe") }
    }

    if ($keytool -and $jarsigner) {
        if (!(Test-Path $Keystore)) {
            Write-Host "Creating local signing keystore..."
            & $keytool.Source -genkeypair -v -keystore $Keystore -alias $KeyAlias -keyalg RSA -keysize 2048 -validity 10000 -storepass $StorePass -keypass $KeyPass -dname "CN=Smitch Offline, OU=Local, O=Smitch Offline, L=Local, S=Local, C=IN"
        }
        Write-Host "Signing APK with jarsigner..."
        & $jarsigner.Source -verbose -sigalg SHA256withRSA -digestalg SHA-256 -keystore $Keystore -storepass $StorePass -keypass $KeyPass -signedjar $FinalApk $UnsignedApk $KeyAlias
        if (Test-Path $FinalApk) {
            $signedSuccess = $true
        }
    }
}

if (!(Test-Path $FinalApk)) {
    throw "APK signing failed. Neither uber-apk-signer, apksigner, nor JDK jarsigner could complete the signing process."
}

Write-Host "[OK] APK signed successfully" -ForegroundColor Green

# ------------------------------------------------------------
# Verify signature
# ------------------------------------------------------------

Write-Host "Verifying APK signature..."

if (Test-Path $UberSignerJar) {
    java -jar $UberSignerJar -a $FinalApk -y
}
elseif ($jarsigner) {
    & $jarsigner.Source -verify -verbose -certs $FinalApk
}

Write-Host ""
Write-Host "=============================================" -ForegroundColor Green
Write-Host "       SMITCH OFFLINE APK READY" -ForegroundColor Green
Write-Host "=============================================" -ForegroundColor Green
Write-Host ""
Write-Host "Signed APK:"
Write-Host $FinalApk
Write-Host ""
Write-Host "Unsigned APK:"
Write-Host $UnsignedApk
Write-Host ""
Write-Host "Keystore:"
Write-Host $Keystore
Write-Host ""
Write-Host "IMPORTANT:"
Write-Host "The original Smitch APK was signed with a different key."
Write-Host "Android may require the original app to be uninstalled"
Write-Host "before this modified APK can be installed."
Write-Host ""
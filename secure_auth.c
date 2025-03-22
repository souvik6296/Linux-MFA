#include <security/pam_appl.h>
#include <security/pam_modules.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <openssl/hmac.h>
#include <openssl/sha.h>
#include <time.h>
#include <ctype.h>  // For toupper()
#include <unistd.h> // For getuid() and getpwuid()
#include <syslog.h>              // For LOG_ERR, LOG_INFO
#include <security/pam_ext.h>    // For pam_syslog, pam_prompt

#define SECRET_FILE "/home/%s/.google_authenticator"  // Secret file path with username

// Base32 decoding function
unsigned char* base32_decode(const char *encoded, size_t *out_length) {
    const char *base32_chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
    size_t input_length = strlen(encoded);
    size_t output_length = (input_length * 5) / 8;  // Base32 decoding output size
    unsigned char *decoded = (unsigned char *)malloc(output_length);
    if (!decoded) {
        return NULL;
    }

    int buffer = 0, bits_left = 0;
    size_t decoded_index = 0;

    for (size_t i = 0; i < input_length; i++) {
        char c = toupper(encoded[i]);  // Convert to uppercase
        const char *ptr = strchr(base32_chars, c);
        if (!ptr) {
            free(decoded);
            return NULL;  // Invalid character
        }

        int value = ptr - base32_chars;
        buffer = (buffer << 5) | value;
        bits_left += 5;

        if (bits_left >= 8) {
            decoded[decoded_index++] = (buffer >> (bits_left - 8)) & 0xFF;
            bits_left -= 8;
        }
    }

    *out_length = decoded_index;
    return decoded;
}

// Generate TOTP
int generate_totp(const char *secret, time_t current_time, unsigned digits) {
    // Decode the base32-encoded secret key
    size_t secret_length;
    unsigned char *decoded_secret = base32_decode(secret, &secret_length);
    if (!decoded_secret) {
        return -1;
    }

    // Calculate the time counter
    time_t time_step = 30;  // 30-second time step
    time_t counter = current_time / time_step;

    // Convert the counter to a byte array (big-endian)
    unsigned char counter_bytes[8];
    for (int i = 7; i >= 0; i--) {
        counter_bytes[i] = counter & 0xFF;
        counter >>= 8;
    }

    // Generate the HMAC-SHA1 hash
    unsigned char hmac_result[SHA_DIGEST_LENGTH];
    HMAC(EVP_sha1(), decoded_secret, secret_length, counter_bytes, 8, hmac_result, NULL);

    // Extract the OTP from the hash
    int offset = hmac_result[SHA_DIGEST_LENGTH - 1] & 0x0F;
    int otp = ((hmac_result[offset] & 0x7F) << 24) |
              ((hmac_result[offset + 1] & 0xFF) << 16) |
              ((hmac_result[offset + 2] & 0xFF) << 8) |
              (hmac_result[offset + 3] & 0xFF);
    otp %= 1000000;  // 6-digit OTP

    // Free the decoded secret
    free(decoded_secret);

    return otp;
}

// PAM authentication function
PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    const char *username;
    char *otp_input = NULL;  // Use a pointer for pam_prompt
    char secret_file[256];

    // Get the username
    if (pam_get_user(pamh, &username, NULL) != PAM_SUCCESS) {
        pam_syslog(pamh, LOG_ERR, "Failed to get username.");
        return PAM_AUTH_ERR;
    }

    // Construct the secret file path
    snprintf(secret_file, sizeof(secret_file), SECRET_FILE, username);

    // Read the secret key from the file
    FILE *file = fopen(secret_file, "r");
    if (!file) {
        pam_syslog(pamh, LOG_ERR, "Cannot open secret file for user %s.", username);
        return PAM_AUTH_ERR;
    }

    char secret[32];
    if (fgets(secret, sizeof(secret), file) == NULL) {
        pam_syslog(pamh, LOG_ERR, "Secret file is empty for user %s.", username);
        fclose(file);
        return PAM_AUTH_ERR;
    }
    fclose(file);

    // Remove newline character if present
    secret[strcspn(secret, "\n")] = '\0';

    // Ask for OTP
    if (pam_prompt(pamh, PAM_PROMPT_ECHO_OFF, &otp_input, "Enter OTP: ") != PAM_SUCCESS) {
        pam_syslog(pamh, LOG_ERR, "Failed to prompt for OTP.");
        return PAM_AUTH_ERR;
    }

    // Get current time
    time_t current_time = time(NULL);

    // Generate TOTP
    int otp = generate_totp(secret, current_time, 6);
    if (otp == -1) {
        pam_syslog(pamh, LOG_ERR, "Failed to generate OTP for user %s.", username);
        return PAM_AUTH_ERR;
    }

    // Compare OTPs
    if (atoi(otp_input) == otp) {
        pam_syslog(pamh, LOG_INFO, "OTP authentication successful for user %s.", username);
        return PAM_SUCCESS;
    } else {
        pam_syslog(pamh, LOG_ERR, "Invalid OTP for user %s. Logging out...", username);

        // Log out the user by closing the session
        pam_close_session(pamh, 0);
        return PAM_AUTH_ERR;
    }
}

// PAM credential management function (not used)
PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags, int argc, const char **argv) {
    return PAM_SUCCESS;
}

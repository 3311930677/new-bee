package online

var genderIDs = []string{"unspecified", "male", "female"}
var avatarIDs = []string{"role_default", "role_zs", "role_ck", "role_fs", "role_fz"}

// Empty/default values stay omitted in the canonical command payload, keeping
// the hash of pre-identity three-field create requests and receipts unchanged.
func normalizeCharacterIdentity(body *createCharacterBody) error {
	if body.GenderID == "unspecified" {
		body.GenderID = ""
	}
	if body.AvatarID == "role_default" {
		body.AvatarID = ""
	}
	if body.GenderID != "" && body.GenderID != "male" && body.GenderID != "female" {
		return bad("invalid_gender", "请选择已开放的性别信息")
	}
	if body.AvatarID != "" {
		allowed := false
		for _, id := range avatarIDs {
			allowed = allowed || body.AvatarID == id
		}
		if !allowed {
			return bad("invalid_avatar", "请选择已开放的职业小像")
		}
	}
	return nil
}

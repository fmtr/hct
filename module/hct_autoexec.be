def autoexec()
    import hct_version
    import string

    var message
    if global.hct==nil        
        message="Successfully loaded TAPP and configured paths for hct version "+hct_version.VERSION+". To use it, you will need to `import hct`, e.g. in `autoexec.be`, Berry Console, etc."
        
    else
        message="Successfully imported hct version "+hct_version.VERSION+". You can now access it using the `hct` module, e.g. in `autoexec.be`, Berry Console, etc."
    end

    log(message,3)

    if hct_version.IS_DEVELOPMENT
        print(message)
    end

end

var mod = module("hct_autoexec")
mod.autoexec=autoexec
return mod
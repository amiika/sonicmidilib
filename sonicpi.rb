require_relative "lib/midilib"

def to_sleep (ticks,ppqn)
  # Converts the time in ticks to time in notes
  return (ticks*1.0)/ppqn
end

def midi_to_seq(path)
  seq = MIDI::Sequence.new()
  File.open(path, 'rb') do | file |
    seq.read(file) do | track, num_tracks, i |
    # puts "read track #{i} of #{num_tracks}"
  end
  end
  seq
end

def midi_to_hash(path)

  seq = midi_to_seq(path)
  melodies = []
  sleeps = []
  lengths = []

  seq.each_with_index do |track,idx|
    if track
      # puts "Track: #{track.name} #{track.events.length}"
      # puts "Instrument: #{track.instrument}"
      track = track.select { |e| e.is_a?(MIDI::NoteOn) }
      melody = []
      slps = []
      notes = []
      total_length = 0.0

      track.each_with_index do |e, i|
        if i>0
          slp_delta = e.time_from_start - track[i-1].time_from_start
          note_event = (i<track.length-1 ? track[i-1] : e)

          dur_delta = note_event.off.time_from_start - note_event.time_from_start
          duration = to_sleep(dur_delta, seq.ppqn)

          notes << note_event.note

          if slp_delta != 0 # If not a chord
            melody.push({note: notes.length>1 ? notes : notes[0], duration: duration})
            notes = []
            slp = to_sleep(slp_delta, seq.ppqn)
            total_length+=slp
            slps << slp
          end

        end
      end
    end
    if melody.length>0
      melodies << melody
      sleeps << slps
      lengths << total_length
    end
  end
  return {tracks: melodies, track_lengths: lengths, sleeps: sleeps}
end

def play_midi(path, synths=[:beep])
  midi_hash = path.is_a?(Hash) ? path : (midi_to_hash path)
  midi_hash[:tracks].each_with_index do |melody,n|
    in_thread do
      melody.each_with_index do |item,i|
        synth synths[n%synths.length], note: item[:note], sustain: item[:duration]*0.8, release: item[:duration]*0.2
        sleep midi_hash[:sleeps][n][i] if midi_hash[:sleeps][n][i]
      end
    end
  end
end
